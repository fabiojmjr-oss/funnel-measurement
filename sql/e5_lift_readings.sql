-- What the change did, and what a reading of it says instead.
--
-- The truth is available here and nowhere else: the same treated subjects walked through the stages as they
-- became and as they were. Every measured lift below is scored against that, at the horizon the reading was
-- taken at, so the error is the reading's and not the sample's.

-- The causal effect, eventually. No day filter at all: this is the change's effect on whether a subject ever
-- reaches the last stage of its funnel, which is the only sense in which "the conversion rate went up" is a
-- statement about conversion rather than about timing.
--
-- The tolerance is four standard errors of a *ratio of two correlated means*, which is not the standard
-- error of either of them. The two worlds share their coin streams, so the numerator and the denominator
-- move together, and the delta method needs all three terms - the variance of each mean and the covariance
-- between them:
--
--   Var(X/Y) = Var(X)/Y^2 + X^2*Var(Y)/Y^4 - 2*X*Cov(X,Y)/Y^3
--
-- Dropping the covariance term overstates the band; pricing only the paired difference and forgetting that
-- the denominator is a sample too understates it. The first version of this file did the second and let a
-- 0.0207 deviation on retencao look like a failure against a 0.0151 band that was measuring the wrong
-- quantity. Where the coupling is perfect - a change that moves only the delay - the three terms cancel to
-- zero and the tolerance is zero, which is correct: not one row differs, so there is nothing to be uncertain
-- about.
CREATE OR REPLACE TABLE lift_eventual AS
WITH last_step AS (SELECT funnel, max(step) AS step FROM stages GROUP BY 1),
treated AS (SELECT DISTINCT subject_id, funnel FROM intervention_subjects WHERE treated),
reached AS (
    SELECT
        t.funnel, t.subject_id,
        max(CASE WHEN e.world = 'actual'         THEN 1 ELSE 0 END) AS in_actual,
        max(CASE WHEN e.world = 'counterfactual' THEN 1 ELSE 0 END) AS in_counterfactual
    FROM treated t
    JOIN last_step l ON l.funnel = t.funnel
    LEFT JOIN intervention_events e
      ON e.subject_id = t.subject_id AND e.step = l.step
    GROUP BY 1, 2
),
agg AS (
    SELECT
        funnel,
        count(*)                                     AS subjects,
        avg(in_actual)                               AS actual_rate,
        avg(in_counterfactual)                       AS counterfactual_rate,
        avg(in_actual - in_counterfactual)           AS mean_difference,
        var_samp(in_actual)                          AS var_actual,
        var_samp(in_counterfactual)                  AS var_counterfactual,
        covar_samp(in_actual, in_counterfactual)     AS covar_worlds,
        sum(CASE WHEN in_actual > in_counterfactual THEN 1 ELSE 0 END) AS subjects_gained,
        sum(CASE WHEN in_actual < in_counterfactual THEN 1 ELSE 0 END) AS subjects_lost
    FROM reached GROUP BY 1
)
SELECT
    f.position,
    a.funnel,
    i.kind,
    i.target_step,
    i.rate_multiplier,
    i.lag_multiplier,
    a.subjects,
    a.counterfactual_rate,
    a.actual_rate,
    a.actual_rate / a.counterfactual_rate - 1.0              AS causal_lift,
    i.rate_multiplier - 1.0                                  AS declared_lift,
    a.mean_difference,
    a.subjects_gained,
    a.subjects_lost,
    4.0 * sqrt(greatest(
        a.var_actual / (a.counterfactual_rate * a.counterfactual_rate)
        + a.actual_rate * a.actual_rate * a.var_counterfactual
            / pow(a.counterfactual_rate, 4)
        - 2.0 * a.actual_rate * a.covar_worlds / pow(a.counterfactual_rate, 3)
    , 0.0) / a.subjects)                                         AS tolerance
FROM agg a
JOIN interventions i ON i.funnel = a.funnel
JOIN funnels f ON f.funnel = a.funnel
ORDER BY f.position;

-- The same causal comparison, taken at a finite horizon - which is the only kind a report can take.
--
-- A cohort is read at maturity m if it arrived at least m days before the as-of day, and a subject counts as
-- converted if it reached the last stage within m days of arriving. Both worlds are read the same way on the
-- same cohorts, so the only thing that changes across the rows of this table is how long the reading waited.
CREATE OR REPLACE TABLE lift_by_maturity AS
WITH bounds AS (SELECT (SELECT value FROM params WHERE key = 'as_of_day') AS as_of),
last_step AS (SELECT funnel, max(step) AS step FROM stages GROUP BY 1),
panel AS (
    SELECT DISTINCT s.subject_id, s.funnel, s.cohort_day, h.maturity
    FROM intervention_subjects s, lift_horizons h, bounds b
    WHERE s.treated AND s.cohort_day <= b.as_of - h.maturity
),
reached AS (
    SELECT
        p.funnel, p.maturity, p.subject_id,
        max(CASE WHEN e.world = 'actual'         THEN 1 ELSE 0 END) AS in_actual,
        max(CASE WHEN e.world = 'counterfactual' THEN 1 ELSE 0 END) AS in_counterfactual
    FROM panel p
    JOIN last_step l ON l.funnel = p.funnel
    LEFT JOIN intervention_events e
      ON e.subject_id = p.subject_id AND e.step = l.step AND e.age_at_stage <= p.maturity
    GROUP BY 1, 2, 3
)
SELECT
    f.position,
    r.funnel,
    i.kind,
    r.maturity,
    count(*)                                            AS subjects,
    avg(r.in_counterfactual)                            AS counterfactual_rate,
    avg(r.in_actual)                                    AS actual_rate,
    avg(r.in_actual) / avg(r.in_counterfactual) - 1.0    AS measured_lift,
    i.rate_multiplier - 1.0                             AS declared_lift,
    (avg(r.in_actual) / avg(r.in_counterfactual) - 1.0) - (i.rate_multiplier - 1.0) AS error,
    4.0 * sqrt(greatest(
        var_samp(r.in_actual) / pow(avg(r.in_counterfactual), 2)
        + pow(avg(r.in_actual), 2) * var_samp(r.in_counterfactual) / pow(avg(r.in_counterfactual), 4)
        - 2.0 * avg(r.in_actual) * covar_samp(r.in_actual, r.in_counterfactual)
            / pow(avg(r.in_counterfactual), 3)
    , 0.0) / count(*))                                  AS tolerance
FROM reached r
JOIN interventions i ON i.funnel = r.funnel
JOIN funnels f ON f.funnel = r.funnel
GROUP BY 1, 2, 3, 4, i.rate_multiplier
HAVING avg(r.in_counterfactual) > 0.0
ORDER BY f.position, r.maturity;

-- The ranking a review actually receives, at every horizon it might have been taken at.
--
-- This is the artefact, not the estimate: six changes were shipped, and the meeting decides which ones to
-- keep. The rank by measured lift is compared against the rank by the effect that actually happened, and the
-- horizon is the only thing that differs between the rows of one funnel.
CREATE OR REPLACE TABLE lift_ranking AS
SELECT
    maturity,
    funnel,
    kind,
    measured_lift,
    declared_lift,
    rank() OVER (PARTITION BY maturity ORDER BY measured_lift DESC)          AS rank_as_measured,
    rank() OVER (PARTITION BY maturity ORDER BY declared_lift DESC, funnel)  AS rank_as_declared,
    measured_lift > 0.0 AND declared_lift = 0.0                             AS credited_with_nothing,
    declared_lift > 0.0 AND measured_lift < declared_lift                   AS understated,
    max(CASE WHEN declared_lift = 0.0 THEN measured_lift END)
        OVER (PARTITION BY maturity)                                        AS best_worthless_lift
FROM lift_by_maturity
ORDER BY maturity, measured_lift DESC;

-- And the comparison a dashboard makes instead, which has no counterfactual in it at all: the window
-- reading of the thirty days before the change against the thirty days after it, on the actual world only.
CREATE OR REPLACE TABLE lift_windows AS
WITH t AS (SELECT value AS day FROM params WHERE key = 'intervention_day'),
w AS (SELECT value AS len FROM params WHERE key = 'window_days'),
last_step AS (SELECT funnel, max(step) AS step FROM stages GROUP BY 1),
conversions AS (
    SELECT e.funnel,
           CASE WHEN e.reached_day < t.day THEN 'before' ELSE 'after' END AS period,
           count(*) AS closed
    FROM intervention_events e, t, w
    JOIN last_step l ON l.funnel = e.funnel AND l.step = e.step
    WHERE e.world = 'actual'
      AND e.reached_day >= t.day - w.len AND e.reached_day < t.day + w.len
    GROUP BY 1, 2
),
arrivals AS (
    SELECT s.funnel,
           CASE WHEN s.cohort_day < t.day THEN 'before' ELSE 'after' END AS period,
           count(*) AS arrived
    FROM subjects s, t, w
    WHERE s.cohort_day >= t.day - w.len AND s.cohort_day < t.day + w.len
    GROUP BY 1, 2
)
SELECT
    f.position,
    a.funnel,
    i.kind,
    max(CASE WHEN a.period = 'before' THEN c.closed / a.arrived::DOUBLE END) AS window_rate_before,
    max(CASE WHEN a.period = 'after'  THEN c.closed / a.arrived::DOUBLE END) AS window_rate_after,
    max(CASE WHEN a.period = 'after'  THEN c.closed / a.arrived::DOUBLE END)
        / max(CASE WHEN a.period = 'before' THEN c.closed / a.arrived::DOUBLE END) - 1.0
                                                                            AS window_lift,
    i.rate_multiplier - 1.0                                                 AS declared_lift
FROM arrivals a
JOIN conversions c ON c.funnel = a.funnel AND c.period = a.period
JOIN interventions i ON i.funnel = a.funnel
JOIN funnels f ON f.funnel = a.funnel
GROUP BY 1, 2, 3, i.rate_multiplier
ORDER BY f.position;
