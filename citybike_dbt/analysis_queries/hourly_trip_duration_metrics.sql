/*
--------------------------------------------------------------------------------
Query: hourly_trip_duration_metrics.sql
--------------------------------------------------------------------------------
Purpose:
  - Validate the aggregations in the 'trip_duration_by_hour' model.
  - Show how trip durations vary by hour across different rider types and time-of-day categories.

Details:
  - Groups by start_hour, time_of_day_category, and rider_type.
  - Displays trip counts, average trip durations, and median trip durations.
  - Rounds numeric values for easier readability.

Insights:
  - Helps identify peak periods with short or long average trip durations.
  - For example, if the average duration during Rush Hour for members is lower,
    it confirms that regular commuters tend to complete shorter trips.
--------------------------------------------------------------------------------
*/
SELECT 
  start_hour, 
  time_of_day_category, 
  rider_type, 
  trips_count, 
  ROUND(avg_duration_minutes, 2) AS avg_duration_minutes, 
  ROUND(median_duration_minutes, 2) AS median_duration_minutes
FROM fct_trip_duration_by_hour
ORDER BY start_hour, rider_type
