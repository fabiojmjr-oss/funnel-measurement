-- The event log: one row per subject and per stage it actually reached.
--
-- A subject walks its funnel one step at a time. It reaches the next stage only if that step's coin
-- comes up, and it arrives there after that step's delay. A subject that fails a step simply has no
-- row for it, or for anything after it - which is the shape a real event table has, and the reason a
-- funnel cannot be read by counting rows per stage without asking when each row happened.
--
-- The two draws of a step use different salts, so whether somebody converts and how long they take
-- are independent by construction. The counter is the subject and the step, so the same subject meets
-- the same coins no matter which order the engine evaluates rows in.

CREATE OR REPLACE TABLE events AS
WITH RECURSIVE walk AS (
    SELECT
        s.subject_id,
        s.funnel,
        st.step,
        st.stage,
        s.cohort_day,
        s.cohort_day::DOUBLE AS reached_day
    FROM subjects s
    JOIN stages st ON st.funnel = s.funnel AND st.step = 1

    UNION ALL

    SELECT
        w.subject_id,
        w.funnel,
        st.step,
        st.stage,
        w.cohort_day,
        w.reached_day + lag_days(w.subject_id * 16 + st.step, 101, st.lag_mean_days) AS reached_day
    FROM walk w
    JOIN stages st ON st.funnel = w.funnel AND st.step = w.step + 1
    WHERE passes(w.subject_id * 16 + st.step, 7, st.pass_rate)
)
SELECT
    subject_id,
    funnel,
    step,
    stage,
    cohort_day,
    reached_day,
    reached_day - cohort_day AS age_at_stage,
    reached_day <= (SELECT value FROM params WHERE key = 'as_of_day') AS observed
FROM walk;
