# Targets:
#   - all: Runs the entire pipeline (load data, dbt deps, seed, run, test)
#   - load: Executes a Python script to load raw CSV data into the database.
#   - deps: Installs dbt dependencies.
#   - seed: Loads static seed files into the database (if any).
#   - run: Runs the dbt models (using --full-refresh to rebuild tables).
#   - test: Runs dbt tests to validate data quality.
#   - docs: Generates dbt documentation; optionally serves the docs.
#   - clean: Cleans up build artifacts (e.g., dbt target/ folder).

DBT_DIR            := citybike_dbt
DBT_PROFILES_DIR   := .

.PHONY: venv all load test_load load-spark deps seed run test docs clean
.DEFAULT_GOAL := all 

# ───────────────────────── virtual‑env logic ──────────────────────
VENV_PATH := $(shell poetry env info -p 2>/dev/null)

# 1. target that guarantees .venv exists.
venv:
ifeq ($(wildcard $(VENV_PATH)/bin/activate),)
	@echo "Creating Poetry venv & installing deps…"
	poetry install --no-interaction --no-ansi
endif

# 2. every recipe will use the venv’s bash
export PATH := $(shell poetry env info -p)/bin:$(PATH)
SHELL       := /bin/bash 
# -------------------------------------------------------------------

all: load deps seed run test

load:
	@echo "Loading raw data into the database..."
	python utils/load_data_serialize.py
test_load:
	@echo "\nTesting loaded data..."
	pytest utils/test_load_data_serialize.py

## Optional to run the data ingestion in a Docker container to ensure a consistent environment.
## Spark sessions utilize JAVA which is not available in the default Python environment.
docker-build:
	@echo "\nBuilding Docker image for data ingestion..."
	docker build -t citybike_dbt:latest .

docker-run:
	@echo "\nRunning Docker container for data ingestion..."
	docker run --rm citybike_dbt:latest

load-spark: docker-build docker-run
## ------------------------------------------------------------------------

deps:
	@echo "\nInstalling dbt dependencies..."
	cd $(DBT_DIR) && dbt deps --profiles-dir $(DBT_PROFILES_DIR)
seed:
	@echo "\nSeeding static data (if any)..."
	cd $(DBT_DIR) && dbt seed --profiles-dir $(DBT_PROFILES_DIR)
run:
	@echo "\nRunning dbt models with full-refresh..."
	cd $(DBT_DIR) && dbt run --profiles-dir $(DBT_PROFILES_DIR) --full-refresh
test:
	@echo "\nRunning dbt tests..."
	cd $(DBT_DIR) && dbt test --profiles-dir $(DBT_PROFILES_DIR)
docs:
	@echo "\nGenerating dbt documentation..."
	cd $(DBT_DIR) && dbt docs generate --profiles-dir $(DBT_PROFILES_DIR)
	@echo "\nServing dbt documentation on port 8080 (Ctrl+C to stop)..."
	cd $(DBT_DIR) && dbt docs serve --profiles-dir $(DBT_PROFILES_DIR) --port 8080
clean:
	@echo "\nCleaning up build artifacts..."
	rm -rf $(DBT_DIR)/target