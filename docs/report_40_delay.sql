-- Mechanism two: move the delay, hold the arrivals flat. The dashboard reading does not move at all -
-- it sits on the eventual rate - while the cohort reading falls away from it. The two readings are
-- answering different questions, and only one of them is the question that was asked.
SELECT
    m                                   AS mean_delay_days,
    round(window_rate, 4)               AS dashboard,
    round(p, 4)                         AS eventual_ceiling,
    round(cohort_rate, 4)               AS cohort_30d,
    round(window_rate / cohort_rate, 4) AS ratio
FROM sweep_lag
WHERE m IN (1, 2, 5, 10, 20, 30, 45, 60)
ORDER BY m;
