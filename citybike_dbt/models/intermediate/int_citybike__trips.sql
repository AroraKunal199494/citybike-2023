/**
  Model: int_citybike__trips
  ---------------------------
  Purpose:
      This intermediate model transforms the standardized raw data from the staging layer into a clean, 
      business-ready dataset for analytics. It derives key time dimensions and calculates important metrics 
      (e.g., trip_distance_km and duration_minutes) to support further analytical models.
  
  Process:
      - Derives a canonical trip_date from the start timestamp.
      - Extracts the start_hour and weekday information (both numeric and categorical) to support time-based analyses.
      - Uses a custom macro (haversine_km) to compute the geospatial distance between start and end points.
      - Calculates trip duration (in minutes) using epoch arithmetic.
  
  Fields:
      - trip_sk, ride_id, rideable_type: Identifiers and type info passed along from the staging model.
      - start_ts, end_ts: Timestamps for trip start and end, used for deriving time dimensions.
      - trip_date: Normalized date (YYYY-MM-DD) of the trip.
      - start_hour: The hour (0-23) when the trip started.
      - weekday_num: Numeric representation of the day-of-week (0-6).
      - weekday_type: Categorical classification of the day (e.g., 'weekday' vs. 'weekend').
      - start_station_id, start_station_name, etc.: Station identifiers and attributes.
      - trip_distance_km: Calculated geospatial distance (in kilometers) using a custom haversine macro.
      - member_casual: Rider membership type.
      - duration_minutes: Calculated duration of the trip in minutes.
  
  Configuration:
      Materialized as a table, making the transformed data available for building your dimension and fact models.
**/
{{ config(
    materialized='table',
    post_hook=["analyze int_citybike__trips"],
    tags=["intermediate", "transformation", "citybike"]
) }}

{% set stg_citybike__trips = ref('stg_citybike__trips') %}

SELECT
    trip_sk,
    ride_id,
    rideable_type,
    start_ts,
    end_ts,
    -- Business-centric time derivations: Establish a uniform trip_date and extract time components.
    DATE_TRUNC('day', start_ts) AS trip_date,
    EXTRACT(hour FROM start_ts) AS start_hour,
    EXTRACT(dow FROM start_ts) AS weekday_num,
    CASE 
        WHEN EXTRACT(dow FROM start_ts) IN (0,6) THEN 'weekend' 
        ELSE 'weekday'
    END AS weekday_type,
    start_station_id,
    start_station_name,
    start_lat,
    start_lng,
    end_station_id,
    end_station_name,
    end_lat,
    end_lng,
    member_casual,
    -- Derived metric: Calculate the trip distance in kilometers using a custom Haversine macro.
    {{ haversine_km('start_lat', 'start_lng', 'end_lat', 'end_lng') }} AS trip_distance_km,
    -- Derived metric: Calculate trip duration in minutes.
    EXTRACT(epoch FROM (end_ts - start_ts)) / 60 AS duration_minutes
FROM {{ stg_citybike__trips }}
