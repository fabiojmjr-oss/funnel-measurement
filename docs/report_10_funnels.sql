-- The six funnels at their last stage, ordered by the only parameter that differs in kind: whether
-- arrivals are growing or shrinking.
SELECT
    funnel,
    arrivals_growth_daily          AS growth_per_day,
    stage,
    round(window_rate, 4)          AS dashboard,
    round(cohort_rate, 4)          AS cohort,
    round(declared_rate, 4)        AS eventual_ceiling,
    round(ratio, 4)                AS dashboard_over_cohort
FROM distortion
ORDER BY growth_per_day;
