-- The same causal comparison at six horizons. Nothing changes across the rows of one funnel except how long
-- the reading waited, and that alone decides what the change appears to have done.
--
-- A change that raised a rate converges to its true lift from below as the horizon outlasts the funnel. A
-- change that only moved a delay starts enormous and decays toward zero. At any single horizon the two are
-- indistinguishable; the shape across horizons is the only thing that separates them.
SELECT
    funnel,
    kind,
    maturity                        AS horizon_days,
    subjects,
    round(counterfactual_rate, 4)   AS rate_if_not_shipped,
    round(actual_rate, 4)           AS rate_as_shipped,
    round(measured_lift, 4)         AS measured_lift,
    round(declared_lift, 4)         AS true_lift,
    round(error, 4)                 AS error,
    round(tolerance, 4)             AS tolerance
FROM lift_by_maturity
ORDER BY position, maturity;
