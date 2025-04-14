/**
  Model: popular_stations_by_weekday
  ----------------------------------
  Purpose:
    Identify and rank bike trip start stations by weekday by joining to date and station dimensions.
  
  Process:
    - Join the int_ model to dim_date on trip_date to obtain the normalized weekday name.
    - Group by station and weekday, counting total trips.
    - Join to dim_stations to bring in station names.
    - Rank each station by trip counts per weekday.
  
  Fields:
    - station_id: Identifier for the station from dim_stations.
    - station_name: Descriptive name of the station.
    - weekday: Weekday name from dim_date.
    - total_trips: Aggregate count of trips initiated at the station on that day.
    - station_rank: Rank of the station’s trip count for that weekday.
  
  Configuration:
    Materialized as a table for efficient lookups in dashboards and reporting.
**/
{{ config(
    materialized='table',
    post_hook=["analyze fct_popular_stations_by_weekday"],
    tags=["advanced", "analytics", "station_usage"]
) }}

{% set int_citybike__trips = ref('int_citybike__trips') %}
{% set dim_date = ref('dim_date') %}
{% set dim_stations = ref('dim_stations') %}

WITH station_weekday_counts AS (
    SELECT 
        t.start_station_id,
        d.weekday AS weekday,
        COUNT(*) AS total_trips
    FROM {{ int_citybike__trips }} t
    JOIN {{ dim_date }} d 
      ON t.trip_date = d.ride_date
    GROUP BY 1, 2
)
SELECT 
    s.station_id,
    s.station_name,
    swc.weekday,
    swc.total_trips,
    RANK() OVER (
        PARTITION BY swc.weekday 
        ORDER BY swc.total_trips DESC
    ) AS station_rank
FROM station_weekday_counts swc
JOIN {{ dim_stations }} s 
    ON swc.start_station_id = s.station_id
