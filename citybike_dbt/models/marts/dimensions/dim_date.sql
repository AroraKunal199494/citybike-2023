/**
  Model: dim_date
  ---------------
  Purpose:
    Build a comprehensive date dimension from the trip start timestamp, providing fields for slicing and dicing our data.
  
  Fields:
    - ride_date: The calendar date (YYYY-MM-DD) of a trip.
    - day: Day of the month.
    - week: Week number.
    - month: Month number.
    - year: Year.
    - weekday: Full weekday name.
    - season: Season label derived from the month (Winter, Spring, Summer, Fall).
  
  Configuration:
    Materialized as a table to join on the date key for fact models.
**/
{{ config(
    materialized='table',
    tags=["dimension", "date"]
) }}

{% set int_citybike__trips = ref('int_citybike__trips') %}

SELECT
    trip_date AS ride_date,
    EXTRACT(day FROM trip_date) AS day,
    EXTRACT(week FROM trip_date) AS week,
    EXTRACT(month FROM trip_date) AS month,
    EXTRACT(year FROM trip_date) AS year,
    dayname(trip_date) AS weekday,
    CASE 
        WHEN EXTRACT(month FROM trip_date) IN (12, 1, 2) THEN 'Winter'
        WHEN EXTRACT(month FROM trip_date) IN (3, 4, 5) THEN 'Spring'
        WHEN EXTRACT(month FROM trip_date) IN (6, 7, 8) THEN 'Summer'
        WHEN EXTRACT(month FROM trip_date) IN (9, 10, 11) THEN 'Fall'
    END AS season
FROM (
    SELECT DISTINCT trip_date
    FROM {{ int_citybike__trips }}
) AS dates
