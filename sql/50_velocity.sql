-- The same four readings, in the time dimension instead of the rate dimension.
--
-- Wave 1 asked what share of subjects reach a stage. This asks how long they take, and the same
-- censoring returns: the subjects who have not reached the stage yet are the slow ones, and every
-- reading that averages over arrivals is averaging over the survivors of a race still being run.
--
--   naive_mean       Mean age at the stage over every conversion observed so far. The number a query
--                    against an event table produces, and the one that cannot be right: the long
--                    conversions of recent cohorts have not happened yet, so they are missing from
--                    their own average.
--   window_mean      The same, restricted to conversions landing in the reporting window. Narrower and
--                    no better.
--   conditional_mean Mature cohorts only, and only conversions inside the maturity window. A defined
--                    quantity - "how long, among those who made it inside thirty days" - and still not
--                    the mean time to the stage.
--   restricted_mean  Mature cohorts, every subject, with anybody who had not converted by day W counted
--                    at W. This is the comparable one: it is defined for everybody, it needs no
--                    assumption about the unconverted, and two funnels can be ranked by it.
--   declared_mean    The sum of the declared mean delays. The answer key, which exists here and in no
--                    real operation.

CREATE OR REPLACE TABLE velocity AS
WITH bounds AS (
    SELECT
        (SELECT value FROM params WHERE key = 'as_of_day')    AS as_of,
        (SELECT value FROM params WHERE key = 'window_days')   AS window_days,
        (SELECT value FROM params WHERE key = 'maturity_days') AS maturity
),
declared AS (
    SELECT
        funnel,
        step,
        stage,
        sum(lag_mean_days) OVER (PARTITION BY funnel ORDER BY step) AS declared_mean
    FROM stages
),
mature AS (
    SELECT s.subject_id, s.funnel, s.cohort_day
    FROM subjects s, bounds b
    WHERE s.cohort_day <= b.as_of - b.maturity
),
naive AS (
    SELECT funnel, step, avg(age_at_stage) AS naive_mean, count(*) AS observed_conversions
    FROM events WHERE observed GROUP BY 1, 2
),
windowed AS (
    SELECT e.funnel, e.step, avg(e.age_at_stage) AS window_mean, count(*) AS window_conversions
    FROM events e, bounds b
    WHERE e.reached_day > b.as_of - b.window_days AND e.reached_day <= b.as_of
    GROUP BY 1, 2
),
conditional AS (
    SELECT
        e.funnel,
        e.step,
        avg(e.age_at_stage)     AS conditional_mean,
        stddev_samp(e.age_at_stage) AS conditional_sd,
        count(*)                AS conditional_n
    FROM events e
    JOIN mature m ON m.subject_id = e.subject_id, bounds b
    WHERE e.age_at_stage <= b.maturity
    GROUP BY 1, 2
),
restricted AS (
    -- Every subject of a mature cohort, at every step, whether they got there or not.
    SELECT
        m.funnel,
        st.step,
        avg(least(coalesce(e.age_at_stage, b.maturity), b.maturity)) AS restricted_mean,
        stddev_samp(least(coalesce(e.age_at_stage, b.maturity), b.maturity)) AS restricted_sd,
        count(*) AS subjects_at_risk
    FROM mature m
    JOIN stages st ON st.funnel = m.funnel
    CROSS JOIN bounds b
    LEFT JOIN events e ON e.subject_id = m.subject_id AND e.step = st.step
    GROUP BY 1, 2
)
SELECT
    f.position,
    d.funnel,
    d.step,
    d.stage,
    d.declared_mean,
    n.naive_mean,
    n.observed_conversions,
    w.window_mean,
    c.conditional_mean,
    c.conditional_sd,
    c.conditional_n,
    r.restricted_mean,
    r.restricted_sd,
    r.subjects_at_risk,
    n.naive_mean / nullif(d.declared_mean, 0) AS naive_over_declared
FROM declared d
JOIN funnels f       ON f.funnel = d.funnel
LEFT JOIN naive n       ON n.funnel = d.funnel AND n.step = d.step
LEFT JOIN windowed w    ON w.funnel = d.funnel AND w.step = d.step
LEFT JOIN conditional c ON c.funnel = d.funnel AND c.step = d.step
LEFT JOIN restricted r  ON r.funnel = d.funnel AND r.step = d.step
ORDER BY f.position, d.step;

-- How each funnel's speed reads, against how fast it is. The two rankings are the finding.
-- The ranks are computed on the last-stage rows only. The first version ranked inside the same query
-- as the QUALIFY that selects them, and a window function runs before QUALIFY - so the ranks were over
-- all twenty-eight stages and came out 1, 2, 3, 5, 8, 15.
CREATE OR REPLACE TABLE speed_ranking AS
WITH final_stage AS (
    SELECT v.*
    FROM velocity v
    QUALIFY v.step = max(v.step) OVER (PARTITION BY v.funnel)
)
SELECT
    v.funnel,
    f.arrivals_growth_daily,
    v.stage,
    v.declared_mean,
    v.naive_mean,
    v.restricted_mean,
    v.naive_over_declared,
    rank() OVER (ORDER BY v.declared_mean DESC) AS rank_actually_slowest,
    rank() OVER (ORDER BY v.naive_mean DESC)     AS rank_reads_slowest
FROM final_stage v
JOIN funnels f ON f.funnel = v.funnel
ORDER BY v.declared_mean DESC;

-- The two time readings derived on paper at step 2, where a single exponential closes.
--
--   conditional = m - W * e^(-W/m) / (1 - e^(-W/m))      the truncated mean of the delay
--   restricted  = (1 - p) * W + p * m * (1 - e^(-W/m))   min(T, W) over everybody, unconverted at W
--
-- The second is worth reading twice: it is the one quantity here that needs no assumption about the
-- subjects who never convert, which is why it is the one that can rank two funnels.
CREATE OR REPLACE TABLE velocity_closed_form AS
WITH bounds AS (SELECT (SELECT value FROM params WHERE key = 'maturity_days')::DOUBLE AS w)
SELECT
    f.position,
    s.funnel,
    s.pass_rate           AS p,
    s.lag_mean_days       AS m,
    b.w,
    s.lag_mean_days - b.w * exp(-b.w / s.lag_mean_days) / (1 - exp(-b.w / s.lag_mean_days))
                          AS conditional_closed,
    (1 - s.pass_rate) * b.w + s.pass_rate * s.lag_mean_days * (1 - exp(-b.w / s.lag_mean_days))
                          AS restricted_closed
FROM stages s
JOIN funnels f ON f.funnel = s.funnel
CROSS JOIN bounds b
WHERE s.step = 2
ORDER BY f.position;

-- Mechanism, isolated: hold the delay and move the arrivals. The naive mean is an average over the
-- conversions that have happened, so growth loads it with young cohorts whose slow cases are still
-- in flight.
CREATE OR REPLACE TABLE sweep_velocity AS
WITH bounds AS (
    SELECT
        (SELECT value FROM params WHERE key = 'as_of_day')    AS as_of,
        (SELECT value FROM params WHERE key = 'maturity_days') AS maturity
),
reference AS (SELECT pass_rate AS p, 20.0 AS m FROM stages WHERE funnel = 'venda' AND step = 2),
grid AS (SELECT (g.n - 30) / 1000.0 AS growth FROM range(0, 61) g(n))
SELECT
    grid.growth,
    r.m                                                     AS declared_mean,
    -- Expected conversions of a cohort observed for `age` days, and their expected total age:
    --   count = p * (1 - e^(-age/m)),  total = p * (m - (m + age) * e^(-age/m))
    sum(pow(1.0 + grid.growth, d.cohort_day)
        * r.p * (r.m - (r.m + (b.as_of - d.cohort_day)) * exp(-(b.as_of - d.cohort_day) / r.m)))
    / sum(pow(1.0 + grid.growth, d.cohort_day)
        * r.p * (1 - exp(-(b.as_of - d.cohort_day) / r.m)))  AS naive_mean,
    max((1 - r.p) * b.maturity + r.p * r.m * (1 - exp(-b.maturity / r.m))) AS restricted_mean
FROM grid, reference r, bounds b, range(0, b.as_of + 1) d(cohort_day)
GROUP BY grid.growth, r.m
ORDER BY grid.growth;
