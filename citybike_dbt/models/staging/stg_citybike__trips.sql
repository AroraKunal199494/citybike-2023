/**
  Model: stg_citybike__trips
  --------------------------
  Purpose:
      This staging model extracts and standardizes raw Citi Bike trip data from the source table 
      'citybike.trips_raw'. It casts columns to the desired types, creates a surrogate key using 
      `dbt_utils.generate_surrogate_key`, and filters out any records with invalid durations.
  
  Process:
      - A surrogate key (trip_sk) is generated to establish consistency across models.
      - Each column is explicitly cast to its target data type for uniformity.
      - Filter logic ensures only trips with a non-negative duration are loaded.
      - Supports incremental builds by loading only new data based on the maximum processed start_ts.
  
  Fields:
      - trip_sk: A system-generated surrogate key derived from ride_id.
      - ride_id: Unique ride identifier.
      - rideable_type: Type of bike used.
      - start_ts: Trip start timestamp.
      - end_ts: Trip end timestamp.
      - start_station_name: Name of the starting station.
      - start_station_id: Identifier for the starting station.
      - end_station_name: Name of the ending station.
      - end_station_id: Identifier for the ending station.
      - start_lat / start_lng: Geographical coordinates for trip start.
      - end_lat / end_lng: Geographical coordinates for trip end.
      - member_casual: The membership type indicating if a rider is a member or a casual user.
  
  Configuration:
      Materialized as an incremental model to handle incoming new data efficiently.
**/
{{ config(
    materialized='incremental',
    unique_key='ride_id',
    post_hook=["analyze stg_citybike__trips"],
    tags=["staging", "raw", "citybike"]
) }}

{% set trips_raw_source = source('citybike', 'trips_raw') %}

SELECT
    -- Generate a surrogate key for consistency across models.
    {{ dbt_utils.generate_surrogate_key(['ride_id']) }} AS trip_sk,

    -- Explicit casting for consistency and downstream compatibility.
    ride_id::varchar AS ride_id,
    rideable_type::varchar AS rideable_type,
    started_at::timestamp AS start_ts,
    ended_at::timestamp AS end_ts,
    start_station_name::varchar AS start_station_name,
    start_station_id::varchar AS start_station_id,
    end_station_name::varchar AS end_station_name,
    end_station_id::varchar AS end_station_id,
    start_lat::double precision AS start_lat,
    start_lng::double precision AS start_lng,
    end_lat::double precision AS end_lat,
    end_lng::double precision AS end_lng,
    member_casual::varchar AS member_casual,
    -- Additional Metadata Columns
    CURRENT_TIMESTAMP AS ingestion_ts,
    filename::varchar AS source_file
FROM {{ trips_raw_source }}
WHERE ((ended_at::timestamp) - (started_at::timestamp)) >= INTERVAL '0 second'
{% if is_incremental() %}
  AND started_at > (SELECT MAX(start_ts) FROM {{ this }})
{% endif %}
