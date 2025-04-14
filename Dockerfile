FROM python:3.11-slim

ENV POETRY_VIRTUALENVS_CREATE=false \
    POETRY_NO_INTERACTION=1 \
    POETRY_VERSION=1.5.1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl build-essential libssl-dev openjdk-17-jdk-headless procps && \
    rm -rf /var/lib/apt/lists/*

RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /app
COPY pyproject.toml poetry.lock* /app/
RUN poetry install --no-root --only main
ENV PYTHONPATH="/usr/local/lib/python3.11/site-packages" \
    PYTHONUNBUFFERED=1
COPY . /app  
RUN rm -rf /app/__pycache__                                   
CMD ["python", "utils/load_data_spark.py"]
