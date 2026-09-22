-- Mechanism, isolated: hold a twenty-day delay and move the arrivals. There is no growth rate at which
-- the naive reading is right - unlike the rate reading of wave 1, which is exact at flat arrivals.
SELECT
    growth                                   AS growth_per_day,
    round(declared_mean, 1)                  AS actually_takes_days,
    round(naive_mean, 3)                     AS reads_as_days,
    round(naive_mean / declared_mean, 4)     AS reads_over_actual,
    round(restricted_mean, 3)                AS restricted_30d
FROM sweep_velocity
WHERE growth IN (-0.03, -0.02, -0.01, 0.0, 0.01, 0.02, 0.03)
ORDER BY growth;
