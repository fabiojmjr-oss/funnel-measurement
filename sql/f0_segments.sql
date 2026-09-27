-- Where the subjects came from, and the fact that it changes.
--
-- Waves 1 to 10 treat a funnel's subjects as one population. They are not: subjects arrive through
-- origins that convert at different rates, and the share arriving through each origin moves. That makes
-- every aggregate reading a weighted average whose weights are themselves a time series, and nothing in
-- a funnel report says so.
--
-- This file assigns each existing subject an origin and walks it again. The subjects, their funnels and
-- their arrival days are the ones sql/10_subjects.sql already produced, so the arrival counts of wave 1
-- are untouched and no published figure from an earlier wave moves. What changes is that the second
-- stage's pass rate is now the declared rate times the origin's multiplier, and both the origin shares
-- and the multipliers drift across the horizon.

-- The declared share and multiplier of each origin, interpolated to the day a subject arrived.
CREATE OR REPLACE MACRO at_day(value_at_zero, value_at_horizon, day) AS
    value_at_zero + (value_at_horizon - value_at_zero)
        * day / (SELECT value FROM params WHERE key = 'as_of_day');

CREATE OR REPLACE TABLE segment_schedule AS
WITH horizon AS (SELECT value AS as_of FROM params WHERE key = 'as_of_day')
SELECT
    s.segment,
    s.position,
    d.cohort_day,
    at_day(s.share_at_zero, s.share_at_horizon, d.cohort_day)           AS share,
    at_day(s.multiplier_at_zero, s.multiplier_at_horizon, d.cohort_day) AS multiplier
FROM segments s, horizon h
CROSS JOIN range(0, h.as_of + 1) d(cohort_day);

-- One origin per subject, drawn against the cumulative share of its own arrival day.
--
-- The cumulative bound is computed from the schedule rather than written down, so a change to the
-- declared shares moves the assignment and cannot leave a stale boundary behind.
CREATE OR REPLACE TABLE segment_draws AS
WITH bounds AS (
    SELECT
        cohort_day,
        segment,
        position,
        multiplier,
        sum(share) OVER (PARTITION BY cohort_day ORDER BY position) AS upper_bound,
        sum(share) OVER (PARTITION BY cohort_day ORDER BY position)
            - share                                                  AS lower_bound
    FROM segment_schedule
)
SELECT
    sub.subject_id,
    sub.funnel,
    sub.cohort_day,
    b.segment,
    b.position   AS segment_position,
    b.multiplier
FROM subjects sub
JOIN bounds b ON b.cohort_day = sub.cohort_day
WHERE u01(sub.subject_id, 4001) >= b.lower_bound
  AND u01(sub.subject_id, 4001) <  b.upper_bound;

-- The walk, with the second stage's pass rate scaled by the subject's origin.
--
-- Salts 7 and 101 again, so a subject meets the same coins as in sql/20_events.sql at every stage the
-- origin does not touch. The origin changes one threshold and nothing else.
CREATE OR REPLACE TABLE segment_events AS
WITH RECURSIVE effective AS (
    SELECT
        d.subject_id, d.funnel, d.cohort_day, d.segment, d.segment_position,
        st.step, st.stage, st.lag_mean_days,
        CASE WHEN st.step = 2 THEN st.pass_rate * d.multiplier ELSE st.pass_rate END AS pass_rate
    FROM segment_draws d
    JOIN stages st ON st.funnel = d.funnel
),
walk AS (
    SELECT
        e.subject_id, e.funnel, e.cohort_day, e.segment, e.segment_position,
        e.step, e.stage, e.cohort_day::DOUBLE AS reached_day
    FROM effective e
    WHERE e.step = 1

    UNION ALL

    SELECT
        w.subject_id, w.funnel, w.cohort_day, w.segment, w.segment_position,
        e.step, e.stage,
        w.reached_day + lag_days(w.subject_id * 16 + e.step, 101, e.lag_mean_days)
    FROM walk w
    JOIN effective e ON e.subject_id = w.subject_id AND e.step = w.step + 1
    WHERE passes(w.subject_id * 16 + e.step, 7, e.pass_rate)
)
SELECT
    subject_id, funnel, cohort_day, segment, segment_position, step, stage, reached_day,
    reached_day - cohort_day AS age_at_stage,
    reached_day <= (SELECT value FROM params WHERE key = 'as_of_day') AS observed
FROM walk;
