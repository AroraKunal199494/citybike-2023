# City Bike Data Engineering Task

## Objective
Use **open source technologies only** to transform and analyze NYC Citi Bike trip data using `dbt`.

## Requirements
- Use `dbt` with an open source database (e.g. SQLite, DuckDB, PostgreSQL)
- Download and unzip this dataset: [2023 Citi Bike Trips (full year)](https://s3.amazonaws.com/tripdata/2023-citibike-tripdata.zip)
- Load one or more of the CSVs into your database
- Create a dbt project to transform the raw data into analytics-ready tables
- Include a setup script (e.g., shell or Python) to load the raw data from the URL into your chosen database

## Output
You should produce transformations and queries that help answer the following:

1. **Most popular start stations per weekday**  
   Identify which stations are most frequently used to start trips, broken down by day of the week.

2. **Trip duration patterns by hour of day**  
   Show how average trip durations vary depending on the hour of day the trip starts (e.g. rush hour vs late night).

3. **Daily trip volume trends**  
   Analyze how the number of trips changes over time. This could include:
   - Daily trip counts
   - Week-to-week or month-to-month trends
   - Seasonal patterns (e.g. summer peaks, winter drops)
   - Any anomalies or interesting changes in usage behavior
   The goal is to observe how demand for bike trips fluctuates throughout the year.

## Deliverables
- Your dbt project folder with models and configurations
- A setup script that can load the CSV data into your database of choice
- Example queries to validate the models and demonstrate insights
