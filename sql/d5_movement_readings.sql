-- What the three movements do to readings that assumed they did not happen.
--
-- Every figure below is computed twice on the same subjects: once on the monotone log of sql/20_events.sql
-- and once on the messy log of sql/d0_movements.sql. The subjects, the arrival days and the ordinary
-- forward coins are identical, so the difference is the movements and nothing else.

-- A cohort reading, the way wave 1 takes one: mature cohorts only, and a subject counts as having reached a
-- stage if it was there within the maturity window.
CREATE OR REPLACE TABLE movement_reach AS
WITH bounds AS (
    SELECT
        (SELECT value FROM params WHERE key = 'as_of_day')     AS as_of,
        (SELECT value FROM params WHERE key = 'maturity_days') AS maturity
),
mature AS (
    SELECT s.subject_id, s.funnel, s.cohort_day
    FROM subjects s, bounds b
    WHERE s.cohort_day <= b.as_of - b.maturity
),
monotone AS (
    SELECT m.funnel, e.step, count(DISTINCT e.subject_id) AS reached
    FROM mature m JOIN events e ON e.subject_id = m.subject_id, bounds b
    WHERE e.age_at_stage <= b.maturity
    GROUP BY 1, 2
),
messy AS (
    SELECT m.funnel, e.step, count(DISTINCT e.subject_id) AS reached
    FROM mature m JOIN messy_walk e ON e.subject_id = m.subject_id, bounds b
    WHERE e.age_at_stage <= b.maturity
    GROUP BY 1, 2
),
denominator AS (SELECT funnel, count(*) AS subjects FROM mature GROUP BY 1),
ceiling AS (
    SELECT funnel, step, exp(sum(ln(pass_rate)) OVER (PARTITION BY funnel ORDER BY step)) AS declared_rate
    FROM stages
)
SELECT
    f.position,
    d.funnel,
    st.step,
    st.stage,
    d.subjects,
    coalesce(mo.reached, 0)                               AS monotone_reached,
    coalesce(me.reached, 0)                               AS messy_reached,
    coalesce(mo.reached, 0) / d.subjects::DOUBLE          AS monotone_rate,
    coalesce(me.reached, 0) / d.subjects::DOUBLE          AS messy_rate,
    c.declared_rate,
    coalesce(me.reached, 0) / d.subjects::DOUBLE / c.declared_rate AS messy_over_ceiling,
    coalesce(mo.reached, 0) / d.subjects::DOUBLE / c.declared_rate AS monotone_over_ceiling
FROM denominator d
JOIN stages st ON st.funnel = d.funnel
JOIN funnels f ON f.funnel = d.funnel
JOIN ceiling c ON c.funnel = d.funnel AND c.step = st.step
LEFT JOIN monotone mo ON mo.funnel = d.funnel AND mo.step = st.step
LEFT JOIN messy me ON me.funnel = d.funnel AND me.step = st.step
ORDER BY f.position, st.step;

-- The step-three derivation, which is where the skip closes on paper.
--
-- A first entry arrives at step three either by passing step two and then step three, or by skipping step
-- two and then passing step three. So the reach rate is [(1 - s)*p2 + s] * p3 against a declared ceiling of
-- p2*p3, and the ratio is 1 + s*(1 - p2)/p2 - strictly above one for any skip rate at all, because the
-- skipper was never subject to the coin the ceiling is built from. A fallback from step three does not
-- enter the derivation: the subject had already touched step three, and "ever reached" cannot be undone.
--
-- Two conditions have to be stated for that sentence to be checkable, and the first version of this file
-- stated neither. The derivation is about *first* entries, so a second entry that reaches step three would
-- push the simulation above the formula; and it is about the eventual walk, so the maturity window that
-- every other reading in this repository applies would pull the simulation below it. Two errors in opposite
-- directions on the same figure, which is why the disagreement showed up on two funnels and not on six.
-- Defect 17: a closed form that is not told which population and which horizon it is about is not a closed
-- form, it is a slogan.
CREATE OR REPLACE TABLE movement_first_entry_reach AS
WITH denominator AS (SELECT funnel, count(*) AS subjects FROM movement_draws GROUP BY 1),
touched AS (
    SELECT funnel, step, count(DISTINCT subject_id) AS reached
    FROM messy_first GROUP BY 1, 2
)
SELECT
    d.funnel,
    t.step,
    d.subjects,
    t.reached,
    t.reached / d.subjects::DOUBLE AS reach_rate
FROM denominator d
JOIN touched t ON t.funnel = d.funnel;

CREATE OR REPLACE TABLE movement_closed_form AS
SELECT
    f.position,
    m.funnel,
    m.skip_rate,
    s2.pass_rate                                                   AS pass_two,
    s3.pass_rate                                                   AS pass_three,
    s2.pass_rate * s3.pass_rate                                    AS declared_ceiling,
    ((1.0 - m.skip_rate) * s2.pass_rate + m.skip_rate) * s3.pass_rate AS derived_reach,
    1.0 + m.skip_rate * (1.0 - s2.pass_rate) / s2.pass_rate        AS derived_over_ceiling,
    fe.reach_rate                                                  AS simulated_reach,
    fe.reach_rate / (s2.pass_rate * s3.pass_rate)                  AS simulated_over_ceiling,
    fe.subjects,
    4.0 * sqrt(fe.reach_rate * (1.0 - fe.reach_rate) / fe.subjects) AS tolerance,
    r.messy_rate                                                   AS windowed_reach,
    r.messy_rate - fe.reach_rate                                   AS window_reentry_gap
FROM movements m
JOIN funnels f ON f.funnel = m.funnel
JOIN stages s2 ON s2.funnel = m.funnel AND s2.step = 2
JOIN stages s3 ON s3.funnel = m.funnel AND s3.step = 3
JOIN movement_first_entry_reach fe ON fe.funnel = m.funnel AND fe.step = 3
JOIN movement_reach r ON r.funnel = m.funnel AND r.step = 3
ORDER BY f.position;

-- What a report gets when it counts rows instead of subjects.
--
-- A re-entry puts a second "reached stage one" in the log, and a fallback puts a second "reached stage k".
-- A funnel read by counting events therefore inflates both ends of the fraction, by different factors.
CREATE OR REPLACE TABLE movement_event_counted AS
WITH bounds AS (SELECT (SELECT value FROM params WHERE key = 'as_of_day') AS as_of),
rows_per_stage AS (
    SELECT funnel, step, count(*) AS events, count(DISTINCT subject_id) AS subjects
    FROM messy_walk, bounds b WHERE reached_day <= b.as_of GROUP BY 1, 2
),
entry_rows AS (SELECT funnel, events AS entry_events, subjects AS entry_subjects
               FROM rows_per_stage WHERE step = 1)
SELECT
    f.position,
    r.funnel,
    r.step,
    st.stage,
    r.events,
    r.subjects,
    r.events / r.subjects::DOUBLE                       AS events_per_subject,
    r.events / e.entry_events::DOUBLE                   AS event_counted_rate,
    r.subjects / e.entry_subjects::DOUBLE               AS subject_counted_rate,
    (r.events / e.entry_events::DOUBLE)
        / (r.subjects / e.entry_subjects::DOUBLE)       AS event_over_subject
FROM rows_per_stage r
JOIN entry_rows e ON e.funnel = r.funnel
JOIN stages st ON st.funnel = r.funnel AND st.step = r.step
JOIN funnels f ON f.funnel = r.funnel
ORDER BY f.position, r.step;

-- And the time to reach a stage, which is now two numbers.
CREATE OR REPLACE TABLE movement_timing AS
WITH bounds AS (SELECT (SELECT value FROM params WHERE key = 'as_of_day') AS as_of),
touches AS (
    SELECT funnel, subject_id, step,
           min(age_at_stage) AS first_touch,
           max(age_at_stage) AS last_touch,
           count(*)          AS visits
    FROM messy_walk, bounds b WHERE reached_day <= b.as_of GROUP BY 1, 2, 3
)
SELECT
    f.position,
    t.funnel,
    t.step,
    st.stage,
    count(*)                                    AS subjects,
    avg(t.first_touch)                          AS mean_first_touch,
    avg(t.last_touch)                           AS mean_last_touch,
    avg(t.last_touch) - avg(t.first_touch)      AS gap_days,
    CASE WHEN avg(t.first_touch) > 0 THEN avg(t.last_touch) / avg(t.first_touch) END AS last_over_first,
    count(*) FILTER (WHERE t.visits > 1) / count(*)::DOUBLE AS share_visited_twice
FROM touches t
JOIN stages st ON st.funnel = t.funnel AND st.step = t.step
JOIN funnels f ON f.funnel = t.funnel
GROUP BY 1, 2, 3, 4
ORDER BY f.position, t.step;

-- The rows a monotone staircase cannot hold, counted.
CREATE OR REPLACE TABLE movement_dropped AS
WITH bounds AS (SELECT (SELECT value FROM params WHERE key = 'as_of_day') AS as_of),
observed AS (SELECT * FROM messy_walk, bounds b WHERE reached_day <= b.as_of)
SELECT
    (SELECT count(*) FROM observed)                                        AS messy_events,
    (SELECT count(*) FROM events WHERE observed)                           AS monotone_events,
    (SELECT count(*) FROM observed WHERE entry = 2)                        AS second_entry_events,
    (SELECT count(*) FROM observed WHERE attempt = 2)                      AS after_fallback_events,
    (SELECT count(*) FROM (
        SELECT subject_id, step FROM observed GROUP BY 1, 2 HAVING count(*) > 1))
                                                                            AS stages_visited_twice,
    (SELECT count(DISTINCT subject_id) FROM observed WHERE entry = 2)      AS subjects_that_returned,
    (SELECT count(DISTINCT subject_id) FROM observed WHERE fell_back)      AS subjects_that_fell_back,
    (SELECT count(DISTINCT d.subject_id) FROM movement_draws d WHERE d.skips) AS subjects_that_skipped,
    (SELECT count(*) FROM observed) / (SELECT count(*) FROM events WHERE observed)::DOUBLE
                                                                            AS events_ratio;
