#!/usr/bin/env python3
"""
load_data.py

Download 2023 Citi Bike CSVs, create a DuckDB database, and ingest the files into
staging.trips_raw with robust logging and error handling.

Usage
-----
python load_data.py --db-path data/duckdb/citybike_2023.duckdb
"""

import os
import io
import sys
import time
import glob
import duckdb
import logging
import zipfile
import pathlib
import requests
import argparse

from tqdm import tqdm
from typing import List
from collections import namedtuple

DATA_URL = "https://s3.amazonaws.com/tripdata/2023-citibike-tripdata.zip"
RAW_DIR = pathlib.Path("data/raw")
DEFAULT_DB_PATH = pathlib.Path("data/duckdb/citybike_2023.duckdb")
DEFAULT_THREADS = os.cpu_count() or 4
IngestStats = namedtuple(
    "IngestStats", ["file", "rows_added", "bytes_mb", "seconds"]
)

def configure_logging(verbose: bool = False) -> None:
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(levelname)s %(name)s — %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

def download_zip(url: str, dest: pathlib.Path) -> pathlib.Path:
    """Stream download the Citi Bike zip file with a progress bar."""
    if dest.exists():
        logging.info("Using cached archive %s", dest)
        return dest

    logging.info("Downloading %s → %s", url, dest)
    try:
        with requests.get(url, stream=True, timeout=30) as r:
            r.raise_for_status()
            total = int(r.headers.get("content-length", 0))
            with open(dest, "wb") as f, tqdm(
                total=total, unit="B", unit_scale=True, desc="download"
            ) as bar:
                for chunk in r.iter_content(chunk_size=1024 * 1024):
                    f.write(chunk)
                    bar.update(len(chunk))
        logging.info("Download complete (%.2f MB)", dest.stat().st_size / 1e6)
        return dest
    except (requests.RequestException, OSError) as exc:
        logging.exception("Failed to download dataset: %s", exc)
        raise

def extract_zip(archive: pathlib.Path, out_dir: pathlib.Path) -> List[pathlib.Path]:
    """
    Recursively extract *all* CSVs from a top-level ZIP that itself contains
    monthly ZIPs. Returns the list of CSV paths.
    """
    logging.info("Extracting %s → %s", archive, out_dir)
    csv_paths: list[pathlib.Path] = []

    try:
        with zipfile.ZipFile(archive) as outer:
            for member in outer.namelist():
                if member.endswith(".zip"):                    # 202301‑citibike‑tripdata.zip …
                    # read the inner‑zip into memory and open it
                    with outer.open(member) as inner_bytes:
                        with zipfile.ZipFile(io.BytesIO(inner_bytes.read())) as inner:
                            for csv in inner.namelist():
                                if csv.endswith(".csv"):
                                    inner.extract(csv, out_dir)
                                    csv_paths.append(out_dir / csv)
                elif member.endswith(".csv"):                   # (rare) CSV directly inside
                    outer.extract(member, out_dir)
                    csv_paths.append(out_dir / member)

        logging.info("Extracted %d CSV files", len(csv_paths))
        return csv_paths
    except (zipfile.BadZipFile, OSError) as exc:
        logging.exception("Extraction failed: %s", exc)
        raise

def ingest_to_duckdb(csv_files: list[pathlib.Path], db_path: pathlib.Path, threads: int) -> None:
    logging.info("Connecting to DuckDB %s (threads=%d)", db_path, threads)
    con = duckdb.connect(str(db_path))
    # Configure parallelism inside DuckDB (single process, multi‑threaded)
    con.execute("PRAGMA threads=%s;" % threads)
    con.execute("PRAGMA enable_progress_bar;")

    # ── destination table (empty) ────────────────────────────────────────────
    first = str(csv_files[0])
    con.execute("CREATE SCHEMA IF NOT EXISTS staging;")
    con.execute(
        """
        CREATE OR REPLACE TABLE staging.trips_raw AS
        SELECT * FROM read_csv_auto(
            $1, 
            filename      = true,
            parallel      = true,
            sample_size   = -1,
            union_by_name = true
        ) WHERE FALSE
        """,
        [first],
    )

    # ── keep only real CSVs ─────────────────────────────────────────────────
    good_files = [
        p for p in csv_files
        if p.stat().st_size > 0 and not p.name.startswith("._")
    ]

    if not good_files:
        logging.error("No usable CSV files found after filtering - aborting.")
        con.close()
        return
    
    skipped = set(csv_files) - set(good_files)
    for p in skipped:
        logging.warning("Skipping %s (size=%d bytes)", p.name, p.stat().st_size)

    # ── per‑file ingest + timing ────────────────────────────────────────────
    table_cols = [c[1] for c in con.execute(
        "PRAGMA table_info('staging.trips_raw');"
    ).fetchall()]
    select_cols = ", ".join(table_cols)

    stats: list[IngestStats] = []
    t0 = time.perf_counter()

    total_rows = 0 
    for i, p in enumerate(good_files, 1):
        rows_before = total_rows
        t_file = time.perf_counter()

        con.execute(
            f"""
            INSERT INTO staging.trips_raw
            SELECT {select_cols}
            FROM read_csv_auto(
                     $1,
                     filename      = true,
                     sample_size   = -1,
                     union_by_name = true
                 )
            """,
            [str(p)],
        )

        sec   = time.perf_counter() - t_file
        # one COUNT after the insert
        total_rows = con.execute(
            "SELECT COUNT(*) FROM staging.trips_raw"
        ).fetchone()[0]
        # rows  = con.execute("SELECT last_insert_rowcount()").fetchone()[0]
        rows = total_rows - rows_before
        mb    = p.stat().st_size / 1e6
        stats.append(IngestStats(p.name, rows, mb, sec))

        logging.info("[%2d/%d] %-30s %6.1f MB %8d rows %5.2fs",
                     i, len(good_files), p.name, mb, rows, sec)

    # ── overall summary ─────────────────────────────────────────────────────
    total_s  = time.perf_counter() - t0
    total_mb = sum(s.bytes_mb for s in stats)
    total_r  = sum(s.rows_added for s in stats)

    logging.info("──────────────────────────────────────────────────────────")
    logging.info("Files ingested : %d", len(stats))
    logging.info("Total size     : %.1f MB", total_mb)
    logging.info("Total rows     : %s", f"{total_r:,}")
    logging.info("Total time     : %.2f s", total_s)
    logging.info("Avg speed      : %.1f MB/s", total_mb / total_s)
    logging.info("──────────────────────────────────────────────────────────")   

    con.close()

def main() -> None:
    parser = argparse.ArgumentParser(description="Load Citi Bike data into DuckDB")
    parser.add_argument(
        "--db-path",
        type=pathlib.Path,
        default=DEFAULT_DB_PATH,
        help="Path to DuckDB file",
    )
    parser.add_argument(
        "--threads",
        type=int,
        default=DEFAULT_THREADS,
        help="Number of CPU threads DuckDB should use (default: all cores)",
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Enable DEBUG logging"
    )
    args = parser.parse_args()
    configure_logging(args.verbose)

    try:
        RAW_DIR.mkdir(parents=True, exist_ok=True)
        args.db_path.parent.mkdir(parents=True, exist_ok=True)

        zip_path = RAW_DIR / pathlib.Path(DATA_URL).name
        csvs = extract_zip(download_zip(DATA_URL, zip_path), RAW_DIR)
        ingest_to_duckdb(csvs, args.db_path, args.threads)

    except Exception as exc:
        logging.error("Fatal error: %s", exc)
        sys.exit(1)


if __name__ == "__main__":
    main()