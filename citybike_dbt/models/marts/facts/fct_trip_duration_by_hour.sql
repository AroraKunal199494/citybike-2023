/**
  Model: trip_duration_by_hour
  -----------------------------
  Purpose:
    Analyze bike trip duration patterns by hour of day, integrating time dimension attributes.
  
  Process:
    - Join the int_ model with dim_time on the start_hour to derive a time_of_day_category.
    - Calculate key duration metrics (count, average, median, 25th and 75th percentiles) for each group.
    - Group the results by start_hour, time_of_day_category, and rider type.
  
  Fields:
    - start_hour: Numeric hour when the trip started.
    - time_of_day_category: Descriptive classification of the hour from dim_time.
    - rider_type: Indicates rider subscription status (e.g., member vs. casual).
    - trips_count: Total number of trips for each grouping.
    - avg_duration_minutes: Average trip duration (minutes).
    - median_duration_minutes: Median trip duration.
    - p25_duration_minutes: 25th percentile for trip durations.
    - p75_duration_minutes: 75th percentile for trip durations.
  
  Configuration:
    Materialized as a table to optimize frequent analytical queries.
**/
{{ config(
    materialized='table',
    post_hook=["analyze fct_trip_duration_by_hour"],
    tags=["advanced", "analytics", "duration_analysis", "time_of_day"]
) }}

{% set int_citybike__trips = ref('int_citybike__trips') %}
{% set dim_time = ref('dim_time') %}

WITH trip_durations AS (
    SELECT 
        t.start_hour,
        dt.time_of_day_category,
        t.member_casual AS rider_type,
        t.duration_minutes
    FROM {{ int_citybike__trips }} t
    JOIN {{ dim_time }} dt 
      ON t.start_hour = dt.hour
)
SELECT
    start_hour,
    time_of_day_category,
    rider_type,
    COUNT(*) AS trips_count,
    AVG(duration_minutes) AS avg_duration_minutes,
    MEDIAN(duration_minutes) AS median_duration_minutes,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY duration_minutes) AS p25_duration_minutes,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY duration_minutes) AS p75_duration_minutes
FROM trip_durations
GROUP BY start_hour, time_of_day_category, rider_type
ORDER BY start_hour, rider_type
