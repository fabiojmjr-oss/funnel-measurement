-- The change somebody shipped, and the world where they did not.
--
-- Waves 1 to 9 measure a funnel. This one measures a *decision*: a change was made on a declared day, and
-- the question is whether the number that moved afterwards is the change. Every funnel here gets one
-- intervention at the same instant, and the six differ only in what kind of thing they changed - two move a
-- pass rate, two move only a delay, one moves both, and one moves nothing at all.
--
-- Two properties of the construction do the work.
--
-- First, common random numbers. The changed world draws the same streams as sql/20_events.sql - salt 7 for
-- the coins and 101 for the delays - so a subject that fails a stage in one world fails it in the other
-- unless the intervention is what changed the outcome. That is a deliberate coupling, and it means the
-- difference between the two worlds is the intervention plus the subjects whose uniform draw falls in the
-- band the multiplier opened, and nothing else. For subjects arriving before the change the two logs are
-- byte-identical, which tests/assert_interventions.sql checks rather than assumes.
--
-- Second, the counterfactual. Every subject arriving on or after the change is walked twice: once through
-- the changed stages and once through the stages as they were. A real operation has the first log and
-- never the second, so the second is the answer key - the causal effect of the change on exactly the
-- population that received it, with no pre-period, no growth, and no mix to argue about. Every measured
-- lift in sql/e5_lift_readings.sql is scored against it.

-- The stages as they were, and as they became.
CREATE OR REPLACE TABLE stages_effective AS
SELECT s.funnel, s.step, s.stage, 'before' AS era, s.pass_rate, s.lag_mean_days
FROM stages s
UNION ALL
SELECT
    s.funnel, s.step, s.stage, 'after',
    s.pass_rate     * CASE WHEN i.target_step = s.step THEN i.rate_multiplier ELSE 1.0 END,
    s.lag_mean_days * CASE WHEN i.target_step = s.step THEN i.lag_multiplier  ELSE 1.0 END
FROM stages s
JOIN interventions i ON i.funnel = s.funnel;

-- Who is walked, in which world, against which set of stages. A subject arriving before the change has one
-- world and it is the one the event log of wave 1 already holds. A subject arriving after it has two.
CREATE OR REPLACE TABLE intervention_subjects AS
WITH t AS (SELECT value AS day FROM params WHERE key = 'intervention_day')
SELECT
    s.subject_id, s.funnel, s.cohort_day, 'actual' AS world,
    CASE WHEN s.cohort_day >= t.day THEN 'after' ELSE 'before' END AS era,
    s.cohort_day >= t.day AS treated
FROM subjects s, t
UNION ALL
SELECT s.subject_id, s.funnel, s.cohort_day, 'counterfactual', 'before', TRUE
FROM subjects s, t
WHERE s.cohort_day >= t.day;

-- The walk, identical in shape to sql/20_events.sql and identical in streams. Only the rate and the delay
-- it reads them against depend on the era.
CREATE OR REPLACE TABLE intervention_events AS
WITH RECURSIVE walk AS (
    SELECT
        b.subject_id, b.funnel, b.world, b.era, b.treated,
        st.step, st.stage, b.cohort_day, b.cohort_day::DOUBLE AS reached_day
    FROM intervention_subjects b
    JOIN stages_effective st ON st.funnel = b.funnel AND st.era = b.era AND st.step = 1

    UNION ALL

    SELECT
        w.subject_id, w.funnel, w.world, w.era, w.treated,
        st.step, st.stage, w.cohort_day,
        w.reached_day + lag_days(w.subject_id * 16 + st.step, 101, st.lag_mean_days)
    FROM walk w
    JOIN stages_effective st
      ON st.funnel = w.funnel AND st.era = w.era AND st.step = w.step + 1
    WHERE passes(w.subject_id * 16 + st.step, 7, st.pass_rate)
)
SELECT
    subject_id, funnel, world, era, treated, step, stage, cohort_day, reached_day,
    reached_day - cohort_day AS age_at_stage,
    reached_day <= (SELECT value FROM params WHERE key = 'as_of_day') AS observed
FROM walk;
