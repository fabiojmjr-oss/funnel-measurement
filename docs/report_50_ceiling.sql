-- Every stage where the dashboard reading exceeds the rate it cannot exceed. A conversion rate above
-- the maximum achievable conversion rate is not a conversion rate.
SELECT
    funnel,
    step,
    stage,
    round(window_rate, 4)                   AS dashboard,
    round(declared_rate, 4)                 AS eventual_ceiling,
    round(window_rate / declared_rate, 4)   AS times_above_ceiling
FROM readings
WHERE step > 1 AND window_rate > declared_rate
ORDER BY times_above_ceiling DESC;
