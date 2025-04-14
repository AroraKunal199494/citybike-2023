/*
--------------------------------------------------------------------------------
Query: monthly_trends.sql
--------------------------------------------------------------------------------
Purpose:
  - Aggregate the daily trip metrics into monthly values to observe seasonal trends.
  
Details:
  - Groups the data by month (using DATE_TRUNC on ride_date).
  - Extracts the total rides per month and month-over-month (MoM) percentage change.
  - Utilizes MAX since month_total and mom_percent_change remain constant within each month group.

Insights:
  - This monthly snapshot can reveal seasonal peaks and troughs.
  - For example, a consistent increase during summer months might indicate higher demand,
    while a decline during winter suggests lower usage.
--------------------------------------------------------------------------------
*/
SELECT 
  DATE_TRUNC('month', ride_date) AS month,
  MAX(month_total) AS total_rides_in_month,
  MAX(mom_percent_change) AS mom_change_percentage
FROM fct_daily_trip_trends
GROUP BY DATE_TRUNC('month', ride_date)
ORDER BY month
