/*
--------------------------------------------------------------------------------
Query: rush_hour_duration_comparison.sql
--------------------------------------------------------------------------------
Purpose:
  - Compare median trip durations between member and casual riders during Rush Hour.
  - Validate the segmentation performed by the 'trip_duration_by_hour' model.

Details:
  - Filters results to include only rows where time_of_day_category is 'Rush Hour'.
  - Uses CASE expressions to separate median durations for members and casual riders.
  - Computes the difference between the two medians for clear comparison.

Insights:
  - A positive duration_difference shows that casual riders are, on average,
    taking longer trips than members during Rush Hour.
  - This information is helpful to tailor service enhancements (e.g., adjusting
    bike availability or marketing strategies).
--------------------------------------------------------------------------------
*/
SELECT
  start_hour,
  time_of_day_category,
  MAX(CASE WHEN rider_type = 'member' THEN median_duration_minutes END) AS member_median_duration,
  MAX(CASE WHEN rider_type = 'casual' THEN median_duration_minutes END) AS casual_median_duration,
  MAX(CASE WHEN rider_type = 'casual' THEN median_duration_minutes END) - 
  MAX(CASE WHEN rider_type = 'member' THEN median_duration_minutes END) AS duration_difference
FROM {{ ref('fct_trip_duration_by_hour') }}
WHERE time_of_day_category = 'Rush Hour'
GROUP BY start_hour, time_of_day_category
ORDER BY start_hour
