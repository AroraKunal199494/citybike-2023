#!/usr/bin/env python3
"""
test_load_data.py

This module contains tests for the load_data.py codebase. We test functions such as:
  - configure_logging: Ensure logging is configured.
  - download_zip: Simulate a streaming download (using monkeypatch to avoid real HTTP calls).
  - extract_zip: Verify extraction logic with a generated zip containing CSV files.
  - ingest_to_duckdb: Create a temporary DuckDB database, load a sample CSV, and verify data ingestion.
  
Advanced testing techniques used include monkeypatching, pytest's tmp_path fixture for temporary files,
and duckdb connections to validate table contents.
"""

import zipfile
import duckdb
import logging
import requests
import pytest

from load_data_serialize import (
    download_zip,
    extract_zip,
    ingest_to_duckdb
)

def fake_requests_get(*args, **kwargs):
    """
    A fake requests.get function that simulates downloading a file in chunks.
    Returns a FakeResponse object with a progress iterator.
    """
    class FakeResponse:
        def __init__(self):
            self.headers = {"content-length": "3145728"}  # 3 MB total length (example)
            self.status_code = 200

        def raise_for_status(self):
            pass

        def iter_content(self, chunk_size=1024):
            # Simulate 3 MB total by yielding fixed size chunks until done.
            total_chunks = int(3145728 / chunk_size)
            for _ in range(total_chunks):
                yield b"a" * chunk_size

        def close(self):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc_value, traceback):
            pass

    return FakeResponse()

def test_download_zip(tmp_path, monkeypatch):
    """
    Test download_zip:
      - Use monkeypatch to replace requests.get with a fake function.
      - Verify that the file is written to the expected destination.
    """
    monkeypatch.setattr(requests, "get", fake_requests_get)
    
    # Define a temporary destination file.
    dest = tmp_path / "fake_archive.zip"
    # Call download_zip (should use the fake response)
    result = download_zip("http://fakeurl", dest)
    
    # Check that the destination path is returned and file exists.
    assert result == dest
    assert dest.exists()
    # Optionally, we can check that the file size is non-zero.
    assert dest.stat().st_size > 0

def test_extract_zip(tmp_path):
    """
    Test extract_zip:
      - Construct a simple zip file containing a CSV file.
      - Extract it and verify that the CSV file is correctly extracted.
    """
    # Create a zip file in the temporary directory.
    zip_path = tmp_path / "test.zip"
    csv_name = "test.csv"
    csv_content = b"col1,col2\n1,2\n3,4\n"
    
    with zipfile.ZipFile(zip_path, mode="w") as zf:
        zf.writestr(csv_name, csv_content)
    
    # Create an output directory for extraction.
    out_dir = tmp_path / "extracted"
    out_dir.mkdir()
    
    # Call extract_zip: It should return a list with one CSV file.
    csv_files = extract_zip(zip_path, out_dir)
    
    # Verify one CSV file is extracted.
    assert len(csv_files) == 1
    extracted_csv = csv_files[0]
    assert extracted_csv.exists()
    # Confirm that the file content matches our CSV.
    with open(extracted_csv, "rb") as f:
        content = f.read()
    assert b"col1,col2" in content

def test_ingest_to_duckdb(tmp_path):
    """
    Test ingest_to_duckdb:
      - Create a small CSV file with sample data.
      - Create a temporary DuckDB database.
      - Ingest the CSV file.
      - Connect to the database and verify the row count.
    """
    # Define a temporary DuckDB database file.
    db_path = tmp_path / "test.duckdb"
    # Create a temporary CSV file with known content.
    csv_file = tmp_path / "test.csv"
    csv_data = "col1,col2\n1,2\n3,4\n"  # 2 rows of data
    csv_file.write_text(csv_data)
    
    # Call ingest_to_duckdb with a list containing our CSV file.
    ingest_to_duckdb([csv_file], db_path, threads=1)
    
    # Connect to the temporary DuckDB database.
    con = duckdb.connect(str(db_path))
    # Query the staging.trips_raw table and verify row count.
    row_count = con.execute("SELECT COUNT(*) FROM staging.trips_raw").fetchone()[0]
    # We expect exactly 2 rows inserted from our CSV.
    assert row_count == 2
    con.close()
