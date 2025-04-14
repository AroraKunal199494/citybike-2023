# Minimal steps to run the solution

**NOTE:** Make sure you have poetry and make installed before running the below commands.

* **git clone <github-url>** # Clone this github repository

* **cd citybike-2023**  # Enter inside the codebase

* **poetry install**   # ≈5 min, Create the Python environment & install deps

* **make all**         # ≈10 min, Execute the full pipeline
    * What happens:
        1. utils/load_data_serialize.py downloads 2023‑citibike‑tripdata.zip (≈ 8 GB), unzips, and ingests every CSV into data/duckdb/citybike_2023.duckdb.
        2. dbt deps → seed → run → test builds all staging/intermediate/mart models and runs data‑quality tests.

## Other extended paths in the makefile
| Target            | Description                                                                                                      |
|-------------------|------------------------------------------------------------------------------------------------------------------|
| `make all`        | End‑to‑end pipeline: download data → load DuckDB → `dbt deps` → `dbt seed` → `dbt run` → `dbt test` → serve docs              |
| `make test`       | Execute **data‑quality tests** only (skips ingestion and model build)                                            |
| `make docs`       | Regenerate and serve **dbt docs** locally on port 8080                                                           |
| `make load-spark` | Use **Apache Spark 3.5** (via Docker) to convert CSV → Parquet, then register Parquet tables in DuckDB           |
| `make test_load`  | Run **pytest** unit tests for the ingestion helpers                                                              |
| `make clean`      | Remove build artefacts (`citybike_dbt/target/`, downloaded zip, temp parquet)                                    |

## Additional resource to verify the work
* There is a Screenshot folder contaning the screenshots from dbt lineage, duckdb database values based on staging, intermediate and final analysis_queries(on fact dbt tables)

## Some reasoning why I choose certain types of technologies
- DuckDB: Zero‑install single‑file DB that’s columnar & vectorised — reviewers don’t need Postgres; still fast enough to scan 70 M rows locally.
- dbt: Industry‑standard transformation framework; brings version control, lineage docs, testing, and environments.
- Make + Poetry: One‑liner developer experience and reproducible dependency management.
- Optional Spark path: Demonstrates ability to switch to distributed compute when data outgrows, while still querying it from DuckDB or dedicated DWH like Snowflake, Databricks etc.

## Some ideas to productionalize the solution

| Aspect            | Quick fix already in repo              | Production‑grade upgrade                                               |
|-------------------|----------------------------------------|------------------------------------------------------------------------|
| **Orchestration** | Manual `make all`                      | Airflow / Dagster DAG triggering nightly `dbt run`                     |
| **Storage**       | DuckDB file on local disk              | Object store (S3) with Iceberg table format; query via DuckDB or DWH   |
| **Incremental**   | `int_citybike__trips` incremental model| Kafka stream → Iceberg partitions hourly                               |
| **Data quality**  | `pytest → dbt run/test`              | Monte Carlo / SodaCL with Slack / PagerDuty alerts                      |
| **Docs**          | `dbt docs serve` locally               | Publish static docs to Netlify/S3; add OpenLineage lineage graph       |
| **CI/CD**         | None| PR‑level data‑diff tests (Elementary) + automated prod deployment via GitHub Action      |
| **Secrets**       | Local `.env` file                      | Vault / AWS Secrets Manager injected into runners & orchestrator       |
| **AWS**           | Laptop / local dev                     | Deploy pipeline & data to AWS services (EC2/ECS/EKS, S3)               |
| **Terraform**     | None        | Manage infrastructure as code (network, S3, EKS, roles) via Terraform  |
| **Docker**        | Optional Spark container               | Containerize entire pipeline; single image for ingestion + dbt         |
| **Kubernetes**    | Single machine                         | Run pipeline as K8s Job or CronJob (scalable, easy rollbacks/updates)  |
