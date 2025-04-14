/**
  Model: daily_trip_trends
  --------------------------
  Purpose:
    Produce an enriched daily time series of bike trips by integrating date dimensions and applying advanced calculations:
      - Daily trip totals.
      - 7-day and 30-day rolling averages for trend analysis.
      - Monthly aggregates and month-over-month percentage change.
      - Season assignment (using the date dimension).
      - Anomaly detection via 30-day rolling statistics.
  
  Process:
    - Join the int_ model to dim_date to use the standardized ride_date.
    - Aggregate the count of trips per day.
    - Compute rolling averages and standard deviation with window functions.
    - Aggregate monthly metrics for MoM change.
    - Join back to dim_date to retrieve the season label.
  
  Fields:
    - ride_date: The date (from dim_date).
    - daily_trips: Total trips on that date.
    - avg_7d_trips: 7-day rolling average.
    - avg_30d_trips: 30-day rolling average.
    - month_total: Sum of trips for the calendar month.
    - prev_month_total: Total trips from the previous month.
    - mom_percent_change: Month-over-month percentage change.
    - season: Season label from dim_date.
    - is_anomaly: Flag if the day deviates more than 3 standard deviations from its 30-day average.
  
  Configuration:
    Materialized as a table for efficient retrieval in time-series dashboards.
**/
{{ config(
    materialized='table',
    post_hook=["analyze fct_daily_trip_trends"],
    tags=["advanced", "analytics", "trend_analysis", "time_series"]
) }}

{% set int_citybike__trips = ref('int_citybike__trips') %}
{% set dim_date = ref('dim_date') %}

WITH daily_counts AS (
    SELECT 
        d.ride_date,
        COUNT(*) AS daily_trips
    FROM {{ int_citybike__trips }} t
    JOIN {{ dim_date }} d 
       ON t.trip_date = d.ride_date
    GROUP BY 1
),
rolling_stats AS (
    SELECT
        ride_date,
        daily_trips,
        AVG(daily_trips) OVER (
            ORDER BY ride_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS avg_7d_trips,
        AVG(daily_trips) OVER (
            ORDER BY ride_date 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS avg_30d_trips,
        STDDEV_POP(daily_trips) OVER (
            ORDER BY ride_date 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS stddev_30d_trips
    FROM daily_counts
),
monthly_trends AS (
    SELECT
        DATE_TRUNC('month', ride_date) AS month_start,
        SUM(daily_trips) AS month_total,
        LAG(SUM(daily_trips)) OVER (
            ORDER BY DATE_TRUNC('month', ride_date)
        ) AS prev_month_total,
        (
          (SUM(daily_trips) - LAG(SUM(daily_trips)) OVER (ORDER BY DATE_TRUNC('month', ride_date))) * 100.0
          / NULLIF(LAG(SUM(daily_trips)) OVER (ORDER BY DATE_TRUNC('month', ride_date)), 0)
        ) AS mom_percent_change
    FROM daily_counts
    GROUP BY 1
)
SELECT
    rs.ride_date,
    rs.daily_trips,
    rs.avg_7d_trips,
    rs.avg_30d_trips,
    mt.month_total,
    mt.prev_month_total,
    mt.mom_percent_change,
    d.season,
    CASE 
        WHEN rs.stddev_30d_trips > 0 
             AND ABS(rs.daily_trips - rs.avg_30d_trips) / rs.stddev_30d_trips > 3
        THEN 1 
        ELSE 0 
    END AS is_anomaly
FROM rolling_stats rs
JOIN monthly_trends mt 
    ON mt.month_start = DATE_TRUNC('month', rs.ride_date)
JOIN {{ dim_date }} d 
    ON rs.ride_date = d.ride_date
