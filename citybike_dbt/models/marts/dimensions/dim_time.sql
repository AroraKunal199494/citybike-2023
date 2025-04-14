/**
  Model: dim_time
  ---------------
  Purpose:
    Create a time dimension that classifies each hour of the day into time-of-day categories.
  
  Fields:
    - hour: Numeric hour extracted from the trip start timestamp (0-23).
    - time_of_day_category: A categorical label assigned based on the hour:
         * "Rush Hour": 7–9 AM and 4–6 PM.
         * "Late Night": 10–11 PM and 12–5 AM.
         * "Other": All other hours.
  
  Configuration:
    Materialized as a table, this dimension supports fact-level grouping and aggregation.
**/
{{ config(
    materialized='table',
    tags=["dimension", "time"]
) }}

{% set int_citybike__trips = ref('int_citybike__trips') %}

SELECT DISTINCT
    start_hour AS hour,
    CASE 
        WHEN start_hour BETWEEN 7 AND 9 
             OR start_hour BETWEEN 16 AND 18 THEN 'Rush Hour'
        WHEN start_hour BETWEEN 0 AND 5 
             OR start_hour BETWEEN 22 AND 23 THEN 'Late Night'
        ELSE 'Other'
    END AS time_of_day_category
FROM {{ int_citybike__trips }}
