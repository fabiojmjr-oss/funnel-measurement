-- The simulation against the algebra, at step 2, where the algebra closes.
--
-- The tolerance is not a guess. Both readings are binomial proportions on a known denominator, so the
-- standard error is computable and the assertion is four of them. A fixed tolerance would either pass
-- a broken resgate - 202 subjects in its window - or fail a correct atendimento with 2,956.
WITH j AS (
    SELECT
        c.funnel,
        c.window_rate_closed        AS p_window,
        r.window_rate               AS sim_window,
        r.entered_in_window         AS n_window,
        c.cohort_rate_closed        AS p_cohort,
        r.cohort_rate               AS sim_cohort,
        (SELECT count(*) FROM subjects s
         WHERE s.funnel = c.funnel
           AND s.cohort_day <= (SELECT value FROM params WHERE key = 'as_of_day')
                             - (SELECT value FROM params WHERE key = 'maturity_days')) AS n_cohort
    FROM closed_form c
    JOIN readings r ON r.funnel = c.funnel AND r.step = 2
)
SELECT 'the simulated window reading is more than four standard errors from the closed form' AS failure,
       funnel AS detail,
       round((sim_window - p_window) / sqrt(p_window * (1 - p_window) / n_window), 3) AS z
FROM j
WHERE abs((sim_window - p_window) / sqrt(p_window * (1 - p_window) / n_window)) > 4.0

UNION ALL
SELECT 'the simulated cohort reading is more than four standard errors from the closed form',
       funnel,
       round((sim_cohort - p_cohort) / sqrt(p_cohort * (1 - p_cohort) / n_cohort), 3)
FROM j
WHERE abs((sim_cohort - p_cohort) / sqrt(p_cohort * (1 - p_cohort) / n_cohort)) > 4.0

UNION ALL
-- And the derivation the whole wave rests on: a cohort read at a fixed age does not know the arrival
-- shape, so its closed form has no growth term in it at all. Asserted as an identity.
SELECT 'the closed-form cohort rate is not the declared truncation of the eventual rate',
       s.funnel,
       round(c.cohort_rate_closed - s.pass_rate * (1 - exp(-30.0 / s.lag_mean_days)), 9)
FROM closed_form c
JOIN stages s ON s.funnel = c.funnel AND s.step = 2
WHERE abs(c.cohort_rate_closed - s.pass_rate * (1 - exp(-30.0 / s.lag_mean_days))) > 1e-9;
