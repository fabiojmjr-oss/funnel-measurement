-- The same queue at three run lengths. Every reading is below the truth, and the shortfall grows with
-- utilisation: near capacity a single busy period holds a fifth of the entire run.
SELECT
    utilisation,
    run_length                                      AS demands_observed,
    busy_periods                                    AS independent_periods,
    biggest_busy_period,
    round(biggest_share_of_run, 4)                  AS biggest_period_share_of_run,
    round(mean_wait_per_day_of_work, 4)             AS reading,
    round(derived_wait, 4)                          AS truth,
    round(mean_wait_per_day_of_work / derived_wait, 4) AS reading_over_truth
FROM queue_run_length
ORDER BY utilisation, run_length;
