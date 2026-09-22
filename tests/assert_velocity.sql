-- The time readings against the algebra, and the properties the wave rests on.
--
-- These are means rather than proportions, so the tolerance is four standard errors computed from the
-- simulation's own spread - `stddev / sqrt(n)` - rather than four of a binomial. Same principle as
-- tests/assert_closed_form.sql and the same reason: retencao has 394 conversions at its last stage and
-- atendimento has 6,533.
WITH j AS (
    SELECT
        v.funnel,
        v.conditional_mean, v.conditional_sd, v.conditional_n,
        c.conditional_closed,
        v.restricted_mean, v.restricted_sd, v.subjects_at_risk,
        c.restricted_closed
    FROM velocity v
    JOIN velocity_closed_form c ON c.funnel = v.funnel
    WHERE v.step = 2
)
SELECT 'the conditional mean is more than four standard errors from the closed form' AS failure,
       funnel AS detail,
       round((conditional_mean - conditional_closed) / (conditional_sd / sqrt(conditional_n)), 3) AS z
FROM j
WHERE abs((conditional_mean - conditional_closed) / (conditional_sd / sqrt(conditional_n))) > 4.0

UNION ALL
SELECT 'the restricted mean is more than four standard errors from the closed form',
       funnel,
       round((restricted_mean - restricted_closed) / (restricted_sd / sqrt(subjects_at_risk)), 3)
FROM j
WHERE abs((restricted_mean - restricted_closed) / (restricted_sd / sqrt(subjects_at_risk))) > 4.0

UNION ALL
-- The naive reading is biased fast at every growth rate in the sweep, including zero. Unlike wave 1's
-- rate reading, which is exactly right at flat arrivals, the time reading has no growth rate at which
-- it is right: even with flat arrivals the young cohorts are there, and their slow cases are not.
SELECT 'the naive time reading was not biased fast at some growth rate', growth::VARCHAR,
       round(naive_mean / declared_mean, 6)
FROM sweep_velocity WHERE naive_mean >= declared_mean

UNION ALL
SELECT 'the naive time reading is not monotone falling in arrival growth', growth::VARCHAR,
       round(naive_mean, 6)
FROM (SELECT growth, naive_mean, lag(naive_mean) OVER (ORDER BY growth) AS previous FROM sweep_velocity)
WHERE previous IS NOT NULL AND naive_mean >= previous

UNION ALL
SELECT 'the restricted mean moved with the arrival growth', growth::VARCHAR, round(restricted_mean, 9)
FROM sweep_velocity
WHERE abs(restricted_mean - (SELECT max(restricted_mean) FROM sweep_velocity)) > 1e-12

UNION ALL
-- A restricted mean caps at the maturity window by construction, so it cannot exceed it.
SELECT 'a restricted mean exceeded the window it is capped at', funnel || ' step ' || step,
       round(restricted_mean, 6)
FROM velocity
WHERE restricted_mean > (SELECT value FROM params WHERE key = 'maturity_days') + 1e-9

UNION ALL
-- And a conditional mean is a truncated mean, so it cannot exceed the window either.
SELECT 'a conditional mean exceeded the window it is truncated at', funnel || ' step ' || step,
       round(conditional_mean, 6)
FROM velocity
WHERE conditional_mean > (SELECT value FROM params WHERE key = 'maturity_days') + 1e-9

UNION ALL
-- The ranking inversion, asserted as the property rather than as two numbers: the funnel that reads
-- slowest is not the slowest funnel.
SELECT 'the slowest funnel is also the one that reads slowest, so the inversion is gone', 'ranking', 0
WHERE (SELECT funnel FROM speed_ranking WHERE rank_actually_slowest = 1)
    = (SELECT funnel FROM speed_ranking WHERE rank_reads_slowest = 1);
