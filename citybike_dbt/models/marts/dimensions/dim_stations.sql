/**
  Model: dim_stations
  -------------------
  Purpose:
    Create a station dimension to store unique bike station attributes derived from the intermediate model.
  
  Fields:
    - station_id: Unique identifier for the station.
    - station_name: Descriptive name for the station.
  
  Notes:
    Additional attributes (e.g. station location, capacity) can be added as available.
  
  Configuration:
    Materialized as a table for rapid joins to fact models.
**/
{{ config(
    materialized='table',
    tags=["dimension", "station"]
) }}

{% set int_citybike__trips = ref('int_citybike__trips') %}

SELECT DISTINCT
    start_station_id AS station_id,
    start_station_name AS station_name
    -- Further attributes can be added here
FROM {{ int_citybike__trips }}
WHERE start_station_id IS NOT NULL
