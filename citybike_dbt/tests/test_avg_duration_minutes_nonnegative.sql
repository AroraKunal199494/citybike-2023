/*
  Test: test_avg_duration_minutes_nonnegative
  -------------------------------------------
  Purpose:
    This test confirms that the avg_duration_minutes value in the fct_trip_duration_by_hour model
    is never negative. A negative average would indicate an error in the calculation logic.
  
  Expected Result:
    The test will pass if it returns 0 rows.
*/

SELECT *
FROM {{ ref('fct_trip_duration_by_hour') }}
WHERE avg_duration_minutes < 0