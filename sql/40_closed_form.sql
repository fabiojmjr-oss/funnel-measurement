-- The same two readings derived on paper, so the simulation is checked against arithmetic.
--
-- Step 2 of every funnel is the case where the algebra closes. A subject reaches it at its arrival day
-- plus one exponential delay, so the chance of having reached it by age t is exactly
-- `p * (1 - exp(-t / m))`. Everything after step 2 is a sum of exponentials and has no expression this
-- short, which is why the verification lives here and the simulation carries the rest.
--
-- Two derivations, and the difference between them is the whole wave:
--
--   cohort_rate  = p * (1 - exp(-W / m))
--     A cohort is read at a fixed age W, so the arrival shape cancels. The rate does not depend on
--     growth at all - which is the property that makes it a rate.
--
--   window_rate  = SUM_s a(s) * p * (exp(-lo(s)/m) - exp(-hi(s)/m))  /  SUM_{s in window} a(s)
--     where hi(s) = T - s and lo(s) = max(0, T - W - s).
--     The numerator runs over **every** cohort that could land a conversion inside the window,
--     including cohorts far older than W. The denominator runs over the cohorts that arrived inside
--     the window. They are different populations, and the ratio inherits the arrival shape.

CREATE OR REPLACE TABLE closed_form AS
WITH bounds AS (
    SELECT
        (SELECT value FROM params WHERE key = 'as_of_day')    AS as_of,
        (SELECT value FROM params WHERE key = 'window_days')   AS window_days,
        (SELECT value FROM params WHERE key = 'maturity_days') AS maturity
),
step2 AS (
    SELECT funnel, pass_rate AS p, lag_mean_days AS m FROM stages WHERE step = 2
),
numerator AS (
    SELECT
        a.funnel,
        sum(
            a.arrivals * s2.p * (
                exp(-greatest(0, b.as_of - b.window_days - a.cohort_day) / s2.m)
                - exp(-(b.as_of - a.cohort_day) / s2.m)
            )
        ) AS expected_reached_in_window
    FROM arrivals a
    JOIN step2 s2 ON s2.funnel = a.funnel
    CROSS JOIN bounds b
    WHERE a.cohort_day <= b.as_of
    GROUP BY 1
),
denominator AS (
    SELECT a.funnel, sum(a.arrivals) AS entered_in_window
    FROM arrivals a, bounds b
    WHERE a.cohort_day > b.as_of - b.window_days AND a.cohort_day <= b.as_of
    GROUP BY 1
)
SELECT
    f.position,
    s2.funnel,
    s2.p,
    s2.m,
    n.expected_reached_in_window / d.entered_in_window                AS window_rate_closed,
    s2.p * (1 - exp(-b.maturity / s2.m))                             AS cohort_rate_closed
FROM step2 s2
JOIN funnels f      ON f.funnel = s2.funnel
JOIN numerator n    ON n.funnel = s2.funnel
JOIN denominator d  ON d.funnel = s2.funnel
CROSS JOIN bounds b
ORDER BY f.position;

-- Mechanism one, in isolation: hold the stage exactly as it is and move only the arrival growth.
-- The cohort rate is flat by derivation; the window rate is not, and it crosses the cohort rate.
CREATE OR REPLACE TABLE sweep_growth AS
WITH bounds AS (
    SELECT
        (SELECT value FROM params WHERE key = 'as_of_day')    AS as_of,
        (SELECT value FROM params WHERE key = 'window_days')   AS window_days,
        (SELECT value FROM params WHERE key = 'maturity_days') AS maturity
),
reference AS (SELECT pass_rate AS p, lag_mean_days AS m FROM stages WHERE funnel = 'venda' AND step = 2),
grid AS (SELECT (g.n - 30) / 1000.0 AS growth FROM range(0, 61) g(n)),
shaped AS (
    SELECT
        grid.growth,
        d.cohort_day,
        pow(1.0 + grid.growth, d.cohort_day) AS arrivals
    FROM grid, bounds b, range(0, b.as_of + 1) d(cohort_day)
)
SELECT
    sh.growth,
    r.p,
    r.m,
    sum(
        CASE WHEN sh.cohort_day <= b.as_of
        THEN sh.arrivals * r.p * (
            exp(-greatest(0, b.as_of - b.window_days - sh.cohort_day) / r.m)
            - exp(-(b.as_of - sh.cohort_day) / r.m))
        ELSE 0 END
    ) / sum(
        CASE WHEN sh.cohort_day > b.as_of - b.window_days AND sh.cohort_day <= b.as_of
        THEN sh.arrivals ELSE 0 END
    )                                                    AS window_rate,
    max(r.p * (1 - exp(-b.maturity / r.m)))               AS cohort_rate
FROM shaped sh, reference r, bounds b
GROUP BY sh.growth, r.p, r.m
ORDER BY sh.growth;

-- Mechanism two, in isolation: hold the arrivals flat and move only the delay. With no growth there
-- is no cohort mix left, and the window reading is still wrong - because its numerator accepts a
-- conversion of any age while its denominator is a window of arrivals.
CREATE OR REPLACE TABLE sweep_lag AS
WITH bounds AS (
    SELECT
        (SELECT value FROM params WHERE key = 'as_of_day')    AS as_of,
        (SELECT value FROM params WHERE key = 'window_days')   AS window_days,
        (SELECT value FROM params WHERE key = 'maturity_days') AS maturity
),
reference AS (SELECT pass_rate AS p FROM stages WHERE funnel = 'venda' AND step = 2),
grid AS (SELECT g.n AS m FROM range(1, 61) g(n))
SELECT
    grid.m,
    r.p,
    sum(
        CASE WHEN d.cohort_day <= b.as_of
        THEN r.p * (
            exp(-greatest(0, b.as_of - b.window_days - d.cohort_day) / grid.m)
            - exp(-(b.as_of - d.cohort_day) / grid.m))
        ELSE 0 END
    ) / sum(
        CASE WHEN d.cohort_day > b.as_of - b.window_days AND d.cohort_day <= b.as_of
        THEN 1 ELSE 0 END
    )                                                     AS window_rate,
    max(r.p * (1 - exp(-b.maturity / grid.m)))              AS cohort_rate
FROM grid, reference r, bounds b, range(0, b.as_of + 1) d(cohort_day)
GROUP BY grid.m, r.p
ORDER BY grid.m;
