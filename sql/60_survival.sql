-- The product-limit estimator, which is the measure the first two waves were missing.
--
-- Waves 1 and 2 diagnosed the same thing twice: a reading that averages over arrivals is averaging over
-- the survivors of a race still being run. Wave 1's answer was to read cohorts old enough to have
-- finished, which is correct and expensive - it throws away every cohort younger than the maturity
-- window, and on this account that is 29.8% of the subjects - a share that grows with the growth
-- rate, so the reading costs most data exactly where the business is moving fastest.
--
-- Kaplan and Meier's estimator does not throw anything away. Each subject contributes for as long as it
-- has been observed and then leaves the risk set: a subject who arrived four days ago tells the estimator
-- what happened in four days and is silent about the fifth. The survival curve is a running product over
-- the daily risk set, which is a window function over a table - so the whole thing is one query and needs
-- no second language either.
--
--   S(t) = PRODUCT over days u <= t of (1 - d_u / n_u)
--
-- where d_u is the events on day u and n_u the subjects still at risk at the start of it. Cumulative
-- incidence is 1 - S(t), and it is defined at every t with no assumption about the subjects who have not
-- converted yet - only that their censoring is unrelated to when they would have converted. Here it is,
-- by construction: censoring is the calendar. In a real funnel it very often is not, and that is the
-- limitation this module has to be read with.

CREATE OR REPLACE TABLE follow_up AS
WITH bounds AS (SELECT (SELECT value FROM params WHERE key = 'as_of_day') AS as_of)
SELECT
    s.subject_id,
    s.funnel,
    st.step,
    st.stage,
    -- Observed time: the age at the stage if it was reached while there was still time to see it,
    -- otherwise how long the subject has been watched.
    CASE
        WHEN e.reached_day IS NOT NULL AND e.reached_day <= b.as_of THEN e.age_at_stage
        ELSE b.as_of - s.cohort_day
    END                                                                      AS observed_days,
    (e.reached_day IS NOT NULL AND e.reached_day <= b.as_of)                  AS had_event
FROM subjects s
JOIN stages st ON st.funnel = s.funnel
CROSS JOIN bounds b
LEFT JOIN events e ON e.subject_id = s.subject_id AND e.step = st.step;

-- The curve, on exact times rather than on days.
--
-- The first version bucketed everything into days with `floor`, which is what a reporting table looks
-- like and is wrong here for a specific reason: a subject that arrived today is censored at zero days
-- of follow-up, and bucketing puts it in the day-zero risk set alongside the events of that day. It
-- cannot have an event - it has had no exposure - so it dilutes the day-zero hazard and every product
-- after it. On `atendimento`, whose delay is a fifth of a day, that pushed the estimate 0.008 below a
-- closed form it should land on.
--
-- So the risk set is counted at each distinct event time: everybody whose observed time is at least
-- that, which is the total minus everybody who left strictly before it. Ordering the records once and
-- taking the smallest row number in each tie group is that count, and it needs one sort.
CREATE OR REPLACE TABLE risk_table AS
WITH ordered AS (
    SELECT
        funnel,
        step,
        stage,
        observed_days,
        had_event,
        count(*) OVER (PARTITION BY funnel, step)                   AS at_risk_start,
        row_number() OVER (
            PARTITION BY funnel, step ORDER BY observed_days, had_event DESC
        )                                                           AS position
    FROM follow_up
)
SELECT
    funnel,
    step,
    stage,
    observed_days                                    AS time,
    count(*) FILTER (WHERE had_event)                AS events,
    count(*) FILTER (WHERE NOT had_event)            AS censored,
    max(at_risk_start) - (min(position) - 1)         AS at_risk
FROM ordered
GROUP BY funnel, step, stage, observed_days
HAVING count(*) FILTER (WHERE had_event) > 0
ORDER BY funnel, step, time;

-- A running product is a running sum of logarithms, which is what a window function gives.
CREATE OR REPLACE TABLE survival AS
SELECT
    funnel,
    step,
    stage,
    time,
    events,
    censored,
    at_risk,
    exp(sum(ln(1.0 - events::DOUBLE / at_risk)) OVER (
        PARTITION BY funnel, step ORDER BY time
    ))                                                              AS survival,
    1.0 - exp(sum(ln(1.0 - events::DOUBLE / at_risk)) OVER (
        PARTITION BY funnel, step ORDER BY time
    ))                                                              AS incidence,
    -- Greenwood's variance of the survival estimate, which is what makes the precision comparable.
    sum(events::DOUBLE / (at_risk * (at_risk - events))) OVER (
        PARTITION BY funnel, step ORDER BY time
    )                                                               AS greenwood_sum
FROM risk_table
WHERE at_risk > events   -- a time that removes the whole risk set ends the curve rather than zeroing it
ORDER BY funnel, step, time;

-- What the estimator says, against what the earlier readings said and against the truth.
CREATE OR REPLACE TABLE survival_readings AS
WITH bounds AS (
    SELECT (SELECT value FROM params WHERE key = 'maturity_days') AS maturity
),
at_window AS (
    SELECT funnel, step, stage, incidence, survival, greenwood_sum
    FROM survival, bounds b
    WHERE time <= b.maturity
    QUALIFY time = max(time) OVER (PARTITION BY funnel, step)
),
plateau AS (
    SELECT funnel, step, incidence AS plateau_incidence
    FROM survival
    QUALIFY time = max(time) OVER (PARTITION BY funnel, step)
),
-- The day by which half of the eventual conversions have happened. The plain median does not exist for
-- a stage most subjects never reach, and most stages here are like that - so the quantity that is
-- always defined is the half-life of the conversions that do happen.
half_life AS (
    SELECT s.funnel, s.step, min(s.time) AS half_life_days
    FROM survival s
    JOIN plateau p ON p.funnel = s.funnel AND p.step = s.step
    WHERE p.plateau_incidence > 0 AND s.incidence >= 0.5 * p.plateau_incidence
    GROUP BY 1, 2
),
-- And the plain median, where it exists at all.
plain_median AS (
    SELECT funnel, step, min(time) AS median_days
    FROM survival WHERE survival <= 0.5 GROUP BY 1, 2
),
eligible AS (
    SELECT s.funnel, count(*) AS n
    FROM subjects s, bounds b
    WHERE s.cohort_day <= (SELECT value FROM params WHERE key = 'as_of_day') - b.maturity
    GROUP BY 1
)
SELECT
    f.position,
    w.funnel,
    w.step,
    w.stage,
    r.declared_rate,
    r.window_rate,
    r.cohort_rate,
    w.incidence                                        AS km_incidence,
    sqrt(w.survival * w.survival * w.greenwood_sum)    AS km_standard_error,
    -- What the cohort reading's interval costs: a binomial on the subjects it was willing to look at.
    sqrt(r.cohort_rate * (1 - r.cohort_rate) / e.n)     AS cohort_standard_error,
    sqrt(w.survival * w.survival * w.greenwood_sum)
        / sqrt(r.cohort_rate * (1 - r.cohort_rate) / e.n) AS standard_error_ratio,
    p.plateau_incidence,
    h.half_life_days,
    m.median_days
FROM at_window w
JOIN funnels f  ON f.funnel = w.funnel
JOIN readings r ON r.funnel = w.funnel AND r.step = w.step
JOIN eligible e ON e.funnel = w.funnel
LEFT JOIN plateau p     ON p.funnel = w.funnel AND p.step = w.step
LEFT JOIN half_life h   ON h.funnel = w.funnel AND h.step = w.step
LEFT JOIN plain_median m ON m.funnel = w.funnel AND m.step = w.step
ORDER BY f.position, w.step;

-- The closed forms at step two, where one exponential closes.
--
--   incidence at W = p * (1 - e^(-W/m))        the same quantity wave 1's cohort reading estimates
--   plateau        = p                          the eventual rate
--   half-life      = m * ln 2                   the median of the delay among the conversions
--
-- The half-life is the one worth noticing: it does not depend on p at all, so it is the only speed
-- measure here that cannot be moved by a change in how many convert.
CREATE OR REPLACE TABLE survival_closed_form AS
WITH bounds AS (SELECT (SELECT value FROM params WHERE key = 'maturity_days')::DOUBLE AS w)
SELECT
    f.position,
    s.funnel,
    s.pass_rate                                   AS p,
    s.lag_mean_days                               AS m,
    s.pass_rate * (1 - exp(-b.w / s.lag_mean_days)) AS incidence_closed,
    s.pass_rate                                   AS plateau_closed,
    s.lag_mean_days * ln(2.0)                     AS half_life_closed
FROM stages s
JOIN funnels f ON f.funnel = s.funnel
CROSS JOIN bounds b
WHERE s.step = 2
ORDER BY f.position;

-- What the cohort reading pays for being right: the subjects it refuses to look at.
CREATE OR REPLACE TABLE data_discarded AS
WITH bounds AS (
    SELECT
        (SELECT value FROM params WHERE key = 'as_of_day')    AS as_of,
        (SELECT value FROM params WHERE key = 'maturity_days') AS maturity
)
SELECT
    count(*)                                                                  AS subjects,
    count(*) FILTER (WHERE s.cohort_day > b.as_of - b.maturity)                AS too_young_for_cohorts,
    count(*) FILTER (WHERE s.cohort_day > b.as_of - b.maturity) / count(*)::DOUBLE AS share_discarded
FROM subjects s, bounds b;
