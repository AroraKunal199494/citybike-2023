#!/usr/bin/env python3
"""
Convert 2023 Citi Bike CSVs to Parquet with Spark and register in DuckDB.

This script downloads the 2023 Citi Bike ZIP archive, extracts all nested CSV files,
converts them to Parquet using Apache Spark, and then creates (or replaces) a DuckDB view
to access the Parquet data. The pipeline provides comprehensive logging, progress indicators,
and reports the overall execution time.

Usage:
    python load_data_parallel.py [--db-path <duckdb_file>] [--verbose]
"""
import argparse
import pathlib
import logging
import zipfile
import io
import requests
import sys
import time

from tqdm import tqdm
from pyspark.sql import SparkSession
import duckdb

# Global Constants
DATA_URL    = "https://s3.amazonaws.com/tripdata/2023-citibike-tripdata.zip"
RAW_DIR     = pathlib.Path("data/raw")
PARQUET_DIR = pathlib.Path("data/parquet/2023")
DB_PATH     = pathlib.Path("data/duckdb/citybike_2023.duckdb")
TMP_DIR     = pathlib.Path("/app/spark-tmp")        # for spills inside Docker

def download_and_extract(url: str, out_dir: pathlib.Path) -> list[pathlib.Path]:
    """
    Download the ZIP archive from the specified URL (if not cached) and extract all CSV files.

    The ZIP archive may contain nested ZIPs. This function extracts every CSV file found
    into the given output directory.

    Parameters:
        url (str): The URL of the ZIP archive to download.
        out_dir (pathlib.Path): The directory where the ZIP and its extracted contents will be stored.

    Returns:
        list[pathlib.Path]: A list of file paths to the extracted CSV files.

    Raises:
        requests.RequestException: If an error occurs during download.
        zipfile.BadZipFile: If the archive is invalid.
        OSError: If any file I/O operation fails.
    """
    try:
        out_dir.mkdir(parents=True, exist_ok=True)
        zip_path = out_dir / pathlib.Path(url).name

        # Download the ZIP file if it doesn't already exist
        if not zip_path.exists():
            logging.info("Downloading %s → %s", url, zip_path)
            with requests.get(url, stream=True, timeout=30) as r:
                r.raise_for_status()
                total = int(r.headers.get("content-length", 0))
                with open(zip_path, "wb") as f, tqdm(total=total, unit="B", unit_scale=True, desc="Downloading") as bar:
                    for chunk in r.iter_content(chunk_size=1 << 20):
                        f.write(chunk)
                        bar.update(len(chunk))
            logging.info("Download complete (%.2f MB)", zip_path.stat().st_size / 1e6)
        else:
            logging.info("Using cached archive %s", zip_path)

        # Extract CSV files from the ZIP (including nested ZIPs)
        csv_files = []
        logging.info("Extracting ZIP archive %s → %s", zip_path, out_dir)
        with zipfile.ZipFile(zip_path) as outer:
            for member in outer.namelist():
                if member.endswith(".zip"):
                    # Open and extract all CSV files in the nested ZIP.
                    with outer.open(member) as inner_bytes:
                        with zipfile.ZipFile(io.BytesIO(inner_bytes.read())) as inner:
                            inner.extractall(out_dir)
                            csv_files += [out_dir / n for n in inner.namelist() if n.endswith(".csv")]
                elif member.endswith(".csv"):
                    # Directly extract CSV files if present at the top level.
                    outer.extract(member, out_dir)
                    csv_files.append(out_dir / member)
        logging.info("Extracted %d CSV files", len(csv_files))
        return csv_files

    except (requests.RequestException, zipfile.BadZipFile, OSError) as exc:
        logging.exception("Failed to download or extract ZIP archive: %s", exc)
        raise

def month_from_name(p: pathlib.Path) -> str:
    # 202301‑citibike‑tripdata.csv → 202301
    return p.stem[:6]

def csvs_to_parquet_stream(csv_files: list[pathlib.Path],
                           pq_dir: pathlib.Path,
                           spark: SparkSession) -> None:
    """
    Convert a list of CSV files to Parquet format using Apache Spark.

    This function reads all CSV files into a Spark DataFrame, extracts the month, 
    repartitions the DataFrame by the month, and writes the data as Parquet files partitioned by month. 
    Progress and timing are logged.

    Parameters:
        csv_files (list[pathlib.Path]): List of CSV file paths.
        pq_dir (pathlib.Path): The directory to store the resulting Parquet files.
        spark (SparkSession): The active Spark session.

    Raises:
        Exception: Propagates any exception during Spark read/write operations.
    """
    try:
        pq_dir.mkdir(parents=True, exist_ok=True)
        for csv in csv_files:
            month = month_from_name(csv)
            out   = pq_dir / f"month={month}"
            logging.info("→ %s (reading %s)", out, csv.name)
            df = spark.read.option("header", True).csv(str(csv))
            df.repartition(4).write.mode("overwrite").parquet(str(out))
    except Exception as exc:
        logging.exception("Error during CSV-to-Parquet conversion: %s", exc)
        raise

def register_parquet_in_duckdb(pq_dir: pathlib.Path, db_path: pathlib.Path) -> None:
    """
    Register the Parquet files in a DuckDB database by creating or replacing a view.

    The function constructs a glob pattern to capture all Parquet files under the specified directory,
    creates (or replaces) a view in the 'staging' schema that reads from these files, and logs the total
    number of rows read.

    Parameters:
        pq_dir (pathlib.Path): The directory where the Parquet files are stored.
        db_path (pathlib.Path): The path to the DuckDB database file.

    Raises:
        Exception: Propagates any database errors (including Binder exceptions).
    """
    try:
        # Build the glob pattern for reading all Parquet files recursively
        glob_path = (pq_dir / "**/*.parquet").as_posix()
        logging.info("Registering Parquet files in DuckDB using glob: %s", glob_path)

        con = duckdb.connect(str(db_path))
        con.execute("CREATE SCHEMA IF NOT EXISTS staging;")
        # Embed the glob pattern directly (placeholders are not supported in DDL)
        con.execute(f"""
            CREATE OR REPLACE TABLE staging.trips_raw AS 
            SELECT * FROM read_parquet('{glob_path}')
        """)
        # Verify by counting rows
        rows = con.execute("SELECT COUNT(*) FROM staging.trips_raw").fetchone()[0]
        logging.info("DuckDB table created successfully - %s rows", f"{rows:,}")
        con.close()

    except Exception as exc:
        logging.exception("Error registering Parquet in DuckDB: %s", exc)
        raise


def main() -> None:
    """
    Main execution function.

    This function performs the following steps:
      1. Parses command-line arguments and configures logging.
      2. Ensures necessary directories exist.
      3. Downloads and extracts the Citi Bike ZIP archive.
      4. Initializes a Spark session with memory and port configurations.
      5. Converts the CSV files to Parquet.
      6. Registers the Parquet files in DuckDB via a view.
      7. Logs the overall execution time.

    Exits with a nonzero status if an unrecoverable error occurs.
    """
    parser = argparse.ArgumentParser(
        description="Convert 2023 Citi Bike CSVs to Parquet using Spark and register in DuckDB."
    )
    parser.add_argument(
        "--db-path",
        type=pathlib.Path,
        default=DB_PATH,
        help="Path to the DuckDB database file."
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable DEBUG-level logging."
    )
    args = parser.parse_args()

    # Configure logging level and format
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s %(levelname)s %(name)s — %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    start_time = time.perf_counter()
    try:
        # Ensure directories exist for raw data and DuckDB database file
        RAW_DIR.mkdir(parents=True, exist_ok=True)
        args.db_path.parent.mkdir(parents=True, exist_ok=True)

        # Download the archive and extract CSV files
        zip_path = RAW_DIR / pathlib.Path(DATA_URL).name
        logging.info("Starting download and extraction process...")
        csv_files = download_and_extract(DATA_URL, RAW_DIR)

        if not csv_files:
            logging.error("No CSV files were extracted. Exiting.")
            sys.exit(1)

        # Configure and start the Spark session with appropriate settings
        logging.info("Starting Spark session...")
        spark = (SparkSession.builder
                 .appName("citibike-csv-to-parquet")
                 .config("spark.sql.execution.arrow.pyspark.enabled", "true")
                 .config("spark.driver.bindAddress", "127.0.0.1")
                 .config("spark.driver.host", "127.0.0.1")
                 .config("spark.driver.memory", "8g")
                 .config("spark.executor.memory", "8g")
                 .config("spark.sql.shuffle.partitions", "24")
                 .getOrCreate())

        # Convert CSVs to Parquet using Spark and log progress
        csvs_to_parquet_stream(csv_files, PARQUET_DIR, spark)
        spark.stop()
        logging.info("Spark session stopped.")

        # Register the resulting Parquet files in DuckDB
        register_parquet_in_duckdb(PARQUET_DIR, args.db_path)

        total_time = time.perf_counter() - start_time
        logging.info("Overall execution time: %.2f seconds.", total_time)

    except Exception as exc:
        logging.error("Fatal error: %s", exc)
        sys.exit(1)


if __name__ == "__main__":
    main()