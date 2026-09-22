-- Mechanism one: move the arrival growth, hold the delay. The cohort reading does not move at all.
SELECT
    growth                             AS growth_per_day,
    round(window_rate, 4)              AS dashboard,
    round(cohort_rate, 4)              AS cohort,
    round(window_rate / cohort_rate, 4) AS ratio
FROM sweep_growth
WHERE growth IN (-0.03, -0.02, -0.01, 0.0, 0.01, 0.02, 0.03)
ORDER BY growth;
