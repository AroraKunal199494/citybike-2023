/*
--------------------------------------------------------------------------------
Query: daily_trips_with_rolling_metrics.sql
--------------------------------------------------------------------------------
Purpose:
  - Validate the 'daily_trip_trends' fact model which provides time series data.
  - Display daily trip counts along with 7-day and 30-day rolling averages and anomaly detection.

Details:
  - Ordered by ride_date to visualize trends over time.
  - The is_anomaly flag identifies days where the trip count deviates significantly
    (more than 3 standard deviations away from the 30-day average).

Insights:
  - An anomaly flag (value 1) helps pinpoint unusual days for further investigation.
  - Rolling averages provide context, making it easier to understand seasonal or trend-based patterns.
--------------------------------------------------------------------------------
*/
SELECT 
  ride_date, 
  daily_trips, 
  ROUND(avg_7d_trips, 1) AS avg_7d_trips, 
  ROUND(avg_30d_trips, 1) AS avg_30d_trips, 
  is_anomaly
FROM {{ ref('fct_daily_trip_trends') }}
ORDER BY ride_date
