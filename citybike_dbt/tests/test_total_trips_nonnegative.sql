/*
  Test: test_total_trips_nonnegative
  ----------------------------------
  Purpose:
    This test verifies that every row in the fct_popular_stations_by_weekday model has a
    nonnegative value in the total_trips column. If any record violates this condition,
    the test will fail.
  
  Expected Result:
    The query should return 0 rows when every record satisfies: total_trips >= 0.
*/

SELECT *
FROM {{ ref('fct_popular_stations_by_weekday') }}
WHERE total_trips < 0