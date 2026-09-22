-- The same account with two classes of subject, built from the identical noise.
--
-- Every uniform is the one the base world already drew: a subject's delay at each step is its base
-- delay multiplied by its class's multiplier, and the class is one new draw on a salt nothing else
-- uses. So the two worlds differ by one structural assumption and by nothing else, which is the only
-- arrangement under which the comparison below means anything.
--
-- The mixture is calibrated to leave the mean delay where it was, so the funnel is exactly as fast on
-- average as it was in waves 1 to 3. What changes is that some subjects were always going to drag.

CREATE OR REPLACE TABLE subject_class AS
SELECT
    s.subject_id,
    s.funnel,
    s.cohort_day,
    CASE WHEN passes(s.subject_id, 613, (SELECT share FROM frailty WHERE class = 'slow'))
         THEN 'slow' ELSE 'fast' END                             AS class
FROM subjects s;

CREATE OR REPLACE TABLE frail_events AS
WITH RECURSIVE multiplier AS (
    SELECT c.subject_id, c.funnel, c.cohort_day, c.class, f.multiplier
    FROM subject_class c
    JOIN frailty f ON f.class = c.class
),
walk AS (
    SELECT
        m.subject_id,
        m.funnel,
        m.class,
        st.step,
        st.stage,
        m.cohort_day,
        m.cohort_day::DOUBLE AS reached_day,
        m.multiplier
    FROM multiplier m
    JOIN stages st ON st.funnel = m.funnel AND st.step = 1

    UNION ALL

    SELECT
        w.subject_id,
        w.funnel,
        w.class,
        st.step,
        st.stage,
        w.cohort_day,
        -- The same uniform as the base world, scaled by the subject's class.
        w.reached_day
            + w.multiplier * lag_days(w.subject_id * 16 + st.step, 101, st.lag_mean_days) AS reached_day,
        w.multiplier
    FROM walk w
    JOIN stages st ON st.funnel = w.funnel AND st.step = w.step + 1
    WHERE passes(w.subject_id * 16 + st.step, 7, st.pass_rate)
)
SELECT
    subject_id,
    funnel,
    class,
    step,
    stage,
    cohort_day,
    reached_day,
    reached_day - cohort_day AS age_at_stage,
    reached_day <= (SELECT value FROM params WHERE key = 'as_of_day') AS observed
FROM walk;

-- The product-limit estimator on the mixture, with nothing archived. It has to be right here, because
-- the classes are a property of the subjects and not of the observation - and it is the control the
-- archived world is read against.
CREATE OR REPLACE TABLE frail_follow_up AS
WITH bounds AS (SELECT (SELECT value FROM params WHERE key = 'as_of_day') AS as_of)
SELECT
    s.subject_id,
    s.funnel,
    st.step,
    st.stage,
    CASE
        WHEN e.reached_day IS NOT NULL AND e.reached_day <= b.as_of THEN e.age_at_stage
        ELSE b.as_of - s.cohort_day
    END                                                                      AS observed_days,
    (e.reached_day IS NOT NULL AND e.reached_day <= b.as_of)                  AS had_event
FROM subjects s
JOIN stages st ON st.funnel = s.funnel
CROSS JOIN bounds b
LEFT JOIN frail_events e ON e.subject_id = s.subject_id AND e.step = st.step;

CREATE OR REPLACE TABLE frail_survival AS
WITH ordered AS (
    SELECT
        funnel, step, stage, observed_days, had_event,
        count(*) OVER (PARTITION BY funnel, step) AS at_risk_start,
        row_number() OVER (PARTITION BY funnel, step ORDER BY observed_days, had_event DESC) AS position
    FROM frail_follow_up
),
risk AS (
    SELECT
        funnel, step, stage,
        observed_days                             AS time,
        count(*) FILTER (WHERE had_event)         AS events,
        max(at_risk_start) - (min(position) - 1)  AS at_risk
    FROM ordered
    GROUP BY funnel, step, stage, observed_days
    HAVING count(*) FILTER (WHERE had_event) > 0
)
SELECT
    funnel, step, stage, time, events, at_risk,
    1.0 - exp(sum(ln(1.0 - events::DOUBLE / at_risk)) OVER (
        PARTITION BY funnel, step ORDER BY time
    )) AS incidence
FROM risk
WHERE at_risk > events
ORDER BY funnel, step, time;

-- The mixture's closed form at step two: a weighted sum of two exponentials, which is exactly what the
-- two classes are.
CREATE OR REPLACE TABLE frailty_closed_form AS
WITH bounds AS (SELECT (SELECT value FROM params WHERE key = 'maturity_days')::DOUBLE AS w)
SELECT
    f.position,
    s.funnel,
    s.pass_rate AS p,
    s.lag_mean_days AS m,
    s.pass_rate * (
        (SELECT share FROM frailty WHERE class = 'slow')
            * (1 - exp(-b.w / (s.lag_mean_days * (SELECT multiplier FROM frailty WHERE class = 'slow'))))
      + (SELECT share FROM frailty WHERE class = 'fast')
            * (1 - exp(-b.w / (s.lag_mean_days * (SELECT multiplier FROM frailty WHERE class = 'fast'))))
    ) AS incidence_closed
FROM stages s
JOIN funnels f ON f.funnel = s.funnel
CROSS JOIN bounds b
WHERE s.step = 2
ORDER BY f.position;
