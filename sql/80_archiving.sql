-- The one assumption wave 3 makes, broken on purpose, and the size of what it costs.
--
-- The estimator needs censoring to be unrelated to when a subject would have converted. Here a review
-- closes the records that look dead, and it is better at spotting the slow class than the fast one - so
-- the subjects it removes had longer to wait than the ones it leaves, and the survivors no longer stand
-- for the departed.
--
-- Nothing in the data records the class. An analyst sees a censoring at day twenty-one and has no way to
-- tell it apart from a calendar censoring, which is why the estimate below is wrong and looks fine.

CREATE OR REPLACE TABLE archive_decisions AS
WITH waits AS (
    -- For every stage a subject reached, how long it waited for the next one. A subject that never
    -- reaches the next stage waits forever, which is what a review sees as a dead record.
    SELECT
        r.subject_id,
        r.funnel,
        r.class,
        r.cohort_day,
        r.step                                                    AS from_step,
        r.reached_day                                             AS from_day,
        coalesce(n.reached_day - r.reached_day, 1e9)                AS wait
    FROM frail_events r
    LEFT JOIN frail_events n ON n.subject_id = r.subject_id AND n.step = r.step + 1
    WHERE EXISTS (SELECT 1 FROM stages s WHERE s.funnel = r.funnel AND s.step = r.step + 1)
),
flagged AS (
    SELECT
        w.*,
        a.stale_days,
        w.wait > a.stale_days
            AND passes(
                w.subject_id * 16 + w.from_step,
                977,
                CASE WHEN w.class = 'slow' THEN a.archive_probability_slow
                     ELSE a.archive_probability_fast END
            )                                                     AS archived
    FROM waits w, archiving a
)
SELECT
    subject_id,
    funnel,
    class,
    cohort_day,
    min(from_step) + 1                                            AS archived_at_step,
    min(from_day + stale_days)                                    AS archived_on_day
FROM flagged
WHERE archived
GROUP BY 1, 2, 3, 4;

-- The follow-up table an analyst would build from the archived data, which is all they can see.
CREATE OR REPLACE TABLE archived_follow_up AS
WITH bounds AS (SELECT (SELECT value FROM params WHERE key = 'as_of_day') AS as_of)
SELECT
    s.subject_id,
    s.funnel,
    st.step,
    st.stage,
    -- Whatever ends the observation first: the archive or the calendar.
    least(
        coalesce(d.archived_on_day, 1e9),
        b.as_of
    ) - s.cohort_day                                                          AS censor_at,
    e.age_at_stage,
    (
        e.reached_day IS NOT NULL
        AND e.reached_day <= least(coalesce(d.archived_on_day, 1e9), b.as_of)
    )                                                                          AS had_event
FROM subjects s
JOIN stages st ON st.funnel = s.funnel
CROSS JOIN bounds b
LEFT JOIN frail_events e ON e.subject_id = s.subject_id AND e.step = st.step
LEFT JOIN archive_decisions d
       ON d.subject_id = s.subject_id AND st.step >= d.archived_at_step;

CREATE OR REPLACE TABLE archived_survival AS
WITH observed AS (
    SELECT
        funnel,
        step,
        stage,
        CASE WHEN had_event THEN age_at_stage ELSE censor_at END AS observed_days,
        had_event
    FROM archived_follow_up
),
ordered AS (
    SELECT
        funnel, step, stage, observed_days, had_event,
        count(*) OVER (PARTITION BY funnel, step) AS at_risk_start,
        row_number() OVER (PARTITION BY funnel, step ORDER BY observed_days, had_event DESC) AS position
    FROM observed
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

-- What the review cost the estimate.
CREATE OR REPLACE TABLE archiving_damage AS
WITH bounds AS (SELECT (SELECT value FROM params WHERE key = 'maturity_days') AS maturity),
honest AS (
    SELECT funnel, step, incidence
    FROM frail_survival, bounds b
    WHERE time <= b.maturity
    QUALIFY time = max(time) OVER (PARTITION BY funnel, step)
),
damaged AS (
    SELECT funnel, step, incidence
    FROM archived_survival, bounds b
    WHERE time <= b.maturity
    QUALIFY time = max(time) OVER (PARTITION BY funnel, step)
),
counted AS (
    SELECT
        funnel,
        count(*)                                        AS archived_subjects,
        count(*) FILTER (WHERE class = 'slow')          AS archived_slow
    FROM archive_decisions
    GROUP BY 1
)
SELECT
    f.position,
    h.funnel,
    h.step,
    s.stage,
    c.declared_rate,
    h.incidence                                AS honest_incidence,
    d.incidence                                AS archived_incidence,
    d.incidence - h.incidence                  AS bias,
    d.incidence / h.incidence                  AS ratio,
    n.archived_subjects,
    n.archived_slow / n.archived_subjects::DOUBLE AS archived_share_slow
FROM honest h
JOIN damaged d  ON d.funnel = h.funnel AND d.step = h.step
JOIN funnels f  ON f.funnel = h.funnel
JOIN stages s   ON s.funnel = h.funnel AND s.step = h.step
JOIN readings c ON c.funnel = h.funnel AND c.step = h.step
LEFT JOIN counted n ON n.funnel = h.funnel
ORDER BY f.position, h.step;

-- What decides how much the review costs: how short its window is against how slow the slow class is.
--
-- The declared twenty-one days is long relative to most of this account's delays, so the review mostly
-- closes records that were never going to convert - and closing a subject that has no event ahead of it
-- costs the estimator almost nothing. Tighten the window and it starts closing records that would have
-- converted, and those are the ones whose absence the survivors are asked to stand for.
--
-- The sweep reuses the same archiving coin at every window, so the comparison is comparative statics on
-- one parameter rather than six separate experiments.
CREATE OR REPLACE TABLE sweep_archiving AS
WITH bounds AS (
    SELECT
        (SELECT value FROM params WHERE key = 'as_of_day')    AS as_of,
        (SELECT value FROM params WHERE key = 'maturity_days') AS maturity
),
grid(stale_days) AS (VALUES (3.0), (5.0), (7.0), (10.0), (14.0), (21.0), (30.0), (45.0), (60.0)),
-- The wait for step two is the wait from the day the subject arrived.
waits AS (
    SELECT
        c.subject_id,
        c.funnel,
        c.class,
        c.cohort_day,
        coalesce(e.reached_day - c.cohort_day, 1e9) AS wait,
        e.reached_day
    FROM subject_class c
    LEFT JOIN frail_events e ON e.subject_id = c.subject_id AND e.step = 2
),
decided AS (
    SELECT
        g.stale_days,
        w.funnel,
        w.cohort_day,
        w.reached_day,
        w.wait > g.stale_days
            AND passes(
                w.subject_id * 16 + 1,
                977,
                CASE WHEN w.class = 'slow' THEN a.archive_probability_slow
                     ELSE a.archive_probability_fast END
            )                                              AS archived,
        g.stale_days                                       AS window_days
    FROM grid g, waits w, archiving a
),
observed AS (
    SELECT
        stale_days,
        funnel,
        CASE
            WHEN reached_day IS NOT NULL
             AND reached_day <= least(
                     CASE WHEN archived THEN cohort_day + window_days ELSE 1e9 END,
                     (SELECT as_of FROM bounds))
            THEN reached_day - cohort_day
            ELSE least(
                     CASE WHEN archived THEN cohort_day + window_days ELSE 1e9 END,
                     (SELECT as_of FROM bounds)) - cohort_day
        END                                                AS observed_days,
        (
            reached_day IS NOT NULL
            AND reached_day <= least(
                    CASE WHEN archived THEN cohort_day + window_days ELSE 1e9 END,
                    (SELECT as_of FROM bounds))
        )                                                  AS had_event
    FROM decided
),
ordered AS (
    SELECT
        stale_days, funnel, observed_days, had_event,
        count(*) OVER (PARTITION BY stale_days, funnel) AS at_risk_start,
        row_number() OVER (
            PARTITION BY stale_days, funnel ORDER BY observed_days, had_event DESC
        ) AS position
    FROM observed
),
risk AS (
    SELECT
        stale_days, funnel,
        observed_days                             AS time,
        count(*) FILTER (WHERE had_event)         AS events,
        max(at_risk_start) - (min(position) - 1)  AS at_risk
    FROM ordered
    GROUP BY stale_days, funnel, observed_days
    HAVING count(*) FILTER (WHERE had_event) > 0
),
curve AS (
    SELECT
        stale_days, funnel, time,
        1.0 - exp(sum(ln(1.0 - events::DOUBLE / at_risk)) OVER (
            PARTITION BY stale_days, funnel ORDER BY time
        )) AS incidence
    FROM risk
    WHERE at_risk > events
),
at_window AS (
    SELECT stale_days, funnel, incidence
    FROM curve, bounds b
    WHERE time <= b.maturity
    QUALIFY time = max(time) OVER (PARTITION BY stale_days, funnel)
),
honest AS (
    SELECT funnel, incidence AS honest_incidence
    FROM frail_survival, bounds b
    WHERE step = 2 AND time <= b.maturity
    QUALIFY time = max(time) OVER (PARTITION BY funnel)
)
SELECT
    a.stale_days,
    a.funnel,
    s.lag_mean_days                                            AS base_lag,
    s.lag_mean_days * (SELECT multiplier FROM frailty WHERE class = 'slow') AS slow_lag,
    a.stale_days / (s.lag_mean_days * (SELECT multiplier FROM frailty WHERE class = 'slow')) AS window_over_slow_lag,
    h.honest_incidence,
    a.incidence                                                AS archived_incidence,
    a.incidence / h.honest_incidence                           AS ratio
FROM at_window a
JOIN honest h ON h.funnel = a.funnel
JOIN stages s ON s.funnel = a.funnel AND s.step = 2
ORDER BY a.funnel, a.stale_days;
