/*
--------------------------------------------------------------------------------
Query: validate_popular_stations_by_weekday.sql
--------------------------------------------------------------------------------
Purpose:
  - Validate the 'popular_stations_by_weekday' fact model by checking its station ranking.
  - Demonstrate business insights into the most popular bike stations on each weekday.

Details:
  - Retrieves the top-ranked station (rank=1) for each weekday.
  - Uses a CASE statement to order weekdays in a logical sequence (Monday -> Sunday).
  - Helps uncover which stations experience the highest volume of trips and thus are key operational hubs.

Expected Outcome:
  - A list of weekdays with the top station name, total trips, and its rank (always 1).
  - Insight into which station dominates on each day, e.g., a major transit hub on weekdays.
--------------------------------------------------------------------------------
*/
SELECT 
  weekday, 
  station_name, 
  total_trips, 
  station_rank
FROM fct_popular_stations_by_weekday
WHERE station_rank = 1
ORDER BY 
  CASE weekday
    WHEN 'Monday' THEN 1
    WHEN 'Tuesday' THEN 2
    WHEN 'Wednesday' THEN 3
    WHEN 'Thursday' THEN 4
    WHEN 'Friday' THEN 5
    WHEN 'Saturday' THEN 6
    WHEN 'Sunday' THEN 7
  END
