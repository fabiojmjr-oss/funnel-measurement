-- The product-limit estimator against the algebra, and the properties that make it the measure.
--
-- Three closed forms at step two, where one exponential closes: the incidence at the window is
-- `p * (1 - e^(-W/m))`, the plateau is `p`, and the half-life of the conversions is `m * ln 2`. The
-- third is the one worth noticing - it does not contain `p`, so it is the only speed measure in this
-- repository that cannot be moved by a change in how many convert.
WITH j AS (
    SELECT
        v.funnel,
        v.km_incidence, v.km_standard_error, c.incidence_closed,
        v.plateau_incidence, c.plateau_closed,
        v.half_life_days, c.half_life_closed
    FROM survival_readings v
    JOIN survival_closed_form c ON c.funnel = v.funnel
    WHERE v.step = 2
)
SELECT 'the estimated incidence is more than four standard errors from the closed form' AS failure,
       funnel AS detail,
       round((km_incidence - incidence_closed) / km_standard_error, 3) AS value
FROM j
WHERE abs((km_incidence - incidence_closed) / km_standard_error) > 4.0

UNION ALL
SELECT 'the plateau is more than four standard errors from the declared eventual rate', funnel,
       round((plateau_incidence - plateau_closed) / km_standard_error, 3)
FROM j
WHERE abs((plateau_incidence - plateau_closed) / km_standard_error) > 4.0

UNION ALL
-- The half-life has no standard error here, so it is asserted on the relative gap, at five per cent.
SELECT 'the half-life is more than five per cent from m * ln 2', funnel,
       round(half_life_days / half_life_closed - 1.0, 4)
FROM j
WHERE abs(half_life_days / half_life_closed - 1.0) > 0.05

UNION ALL
-- A survival curve only falls, and an incidence only rises. Both follow from the product being over
-- factors in [0, 1), and a violation means the risk set was counted wrong.
SELECT 'the survival curve rose', funnel || ' step ' || step, round(survival, 6)
FROM (
    SELECT funnel, step, time, survival,
           lag(survival) OVER (PARTITION BY funnel, step ORDER BY time) AS previous
    FROM survival
)
WHERE previous IS NOT NULL AND survival > previous + 1e-12

UNION ALL
SELECT 'a survival value left the unit interval', funnel || ' step ' || step, round(survival, 6)
FROM survival WHERE survival < 0.0 OR survival > 1.0

UNION ALL
-- The risk set can only shrink as time passes, because nobody re-enters.
SELECT 'the risk set grew', funnel || ' step ' || step, at_risk::DOUBLE
FROM (
    SELECT funnel, step, time, at_risk,
           lag(at_risk) OVER (PARTITION BY funnel, step ORDER BY time) AS previous
    FROM risk_table
)
WHERE previous IS NOT NULL AND at_risk > previous

UNION ALL
-- The exact criterion for a median to exist: more than half the subjects have to reach the stage. Any
-- stage where the two disagree means one of them is computed wrong, and on this account fourteen of
-- twenty-two stages have no median - so "median time to close" is usually a different number.
SELECT 'a median exists where the plateau says it cannot, or the reverse', funnel || ' step ' || step,
       round(plateau_incidence, 4)
FROM survival_readings
WHERE step > 1 AND (median_days IS NULL) <> (plateau_incidence <= 0.5)

UNION ALL
-- And the claim the wave is for: the estimator uses every subject, so its interval is never wider than
-- the cohort reading's, which refuses to look at the young ones.
SELECT 'the estimator was less precise than the cohort reading it replaces', funnel || ' step ' || step,
       round(standard_error_ratio, 4)
FROM survival_readings
WHERE step > 1 AND standard_error_ratio >= 1.0;
