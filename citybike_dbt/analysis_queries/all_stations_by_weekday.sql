/*
--------------------------------------------------------------------------------
Query: all_stations_by_weekday.sql
--------------------------------------------------------------------------------
Purpose:
  - Validate and inspect the full ranking of stations per weekday from the
    'popular_stations_by_weekday' model.
  - Provide a comprehensive list of stations, their trip counts, and ranking.
  
Details:
  - Orders results by weekday and then rank.
  - Aids in identifying not only the top station but also the distribution of trip
    volumes across all stations.
  
Insights:
  - For example, you might see that on weekends the top-ranked station has lower
    volume compared to weekdays, suggesting different usage patterns.
--------------------------------------------------------------------------------
*/
SELECT 
  weekday, 
  station_name, 
  total_trips, 
  station_rank
FROM fct_popular_stations_by_weekday
ORDER BY weekday, station_rank
