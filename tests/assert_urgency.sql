-- The composition of two derivations, and the rule that picks the right order out of six.
--
-- Cobham's formula applies to the labels, and the wait of a true class is a conditional average over the
-- labels its members land in. That is two derivations multiplied together, which is one more step than
-- anywhere else in this repository, so both halves are checked against the simulation separately: the label
-- waits first, then the composition onto the classes.
SELECT 'a label wait is more than four clustered standard errors from Cobham''s formula' AS failure,
       priority AS detail,
       round((simulated_wait - derived_wait) / wait_standard_error, 3) AS value
FROM triage_label_closed_form
WHERE abs(simulated_wait - derived_wait) > 4.0 * wait_standard_error

UNION ALL
SELECT 'a true-class wait is more than four clustered standard errors from the composition', priority,
       round((simulated_wait - derived_wait) / wait_standard_error, 3)
FROM triage_closed_form
WHERE abs(simulated_wait - derived_wait) > 4.0 * wait_standard_error

UNION ALL
SELECT 'the composition weights for a class do not sum to one', priority,
       round(probability_total - 1.0, 15)
FROM triage_closed_form WHERE abs(probability_total - 1.0) > 1e-12

UNION ALL
-- The label waits have to be ordered by the ranking, or Cobham has been fed the utilisations out of order.
SELECT 'a label wait is not ordered by rank', priority, round(derived_wait, 6)
FROM (
    SELECT priority, rnk, derived_wait,
           lag(derived_wait) OVER (ORDER BY rnk) AS better_ranked
    FROM triage_label_closed_form
)
WHERE better_ranked IS NOT NULL AND derived_wait <= better_ranked

UNION ALL
-- The invariance, across every one of the six possible orders.
SELECT 'the work-weighted waiting is not the same under all six orders', 'orders',
       round(spread, 15)
FROM (
    SELECT (max(work_weighted_waiting) - min(work_weighted_waiting)) / max(work_weighted_waiting) AS spread
    FROM urgency_orders
)
WHERE spread > 1e-12

UNION ALL
-- And across every point of both escalation sweeps, which is sixteen relabellings of the same demands.
SELECT 'the work-weighted waiting moved somewhere in the escalation sweep', 'sweep',
       round(spread, 15)
FROM (
    SELECT (max(work_weighted_waiting) - min(work_weighted_waiting)) / max(work_weighted_waiting) AS spread
    FROM escalation_sweep
)
WHERE spread > 1e-12

UNION ALL
-- The rule. Ranking by urgency over mean handling time has to reproduce the order that came out best of the
-- six, and the enumeration is what makes that a test: the rule was not told which candidates existed.
SELECT 'the rule does not reproduce the best of the six enumerated orders', 'rule',
       0
WHERE (
    SELECT string_agg(priority, ' ' ORDER BY rule_rank) FROM urgency_rule
) <> (
    -- The winner is recomputed from `weighted_waiting` rather than read out of the stored `is_best` flag.
    SELECT ordering FROM urgency_orders
    QUALIFY weighted_waiting = min(weighted_waiting) OVER ()
)

UNION ALL
SELECT 'more or fewer than one of the six orders came out best', 'count', n
FROM (
    SELECT count(*) AS n FROM (
        SELECT ordering FROM urgency_orders
        QUALIFY weighted_waiting = min(weighted_waiting) OVER ()
    )
) WHERE n <> 1

UNION ALL
SELECT 'the six enumerated orders are not six distinct orders', 'count',
       count(DISTINCT ordering)::DOUBLE FROM urgency_orders
HAVING count(DISTINCT ordering) <> 6

UNION ALL
-- The sharpest result of the wave, asserted as the exact statement it is: sorting the six orders by what
-- they truly cost puts the reported per-demand mean in strictly decreasing order. Not correlated with the
-- truth, and not uncorrelated - exactly reversed, on all six.
SELECT 'the reported mean wait does not rank the six orders in exactly reverse order', ordering,
       round(mean_wait_per_demand, 4)
FROM (
    SELECT ordering, weighted_waiting, mean_wait_per_demand,
           lag(mean_wait_per_demand) OVER (ORDER BY weighted_waiting) AS previous
    FROM urgency_orders
)
WHERE previous IS NOT NULL AND mean_wait_per_demand >= previous

UNION ALL
-- The two error directions are not worth the same effort, and the assertion is that under-recognition is the
-- expensive one at every matched rate rather than on average.
SELECT 'under-recognition was not worse than over-escalation for the critical class at this rate',
       'rate ' || o.rate, round(u.critical_wait - o.critical_wait, 6)
FROM escalation_sweep o
JOIN escalation_sweep u ON u.rate = o.rate AND u.direction = 'under'
WHERE o.direction = 'over' AND o.rate > 0.0 AND u.critical_wait <= o.critical_wait

UNION ALL
-- Escalating everything is exactly the same as not sorting at all, which is the limit that says the sweep is
-- wired up to the right formula.
SELECT 'escalating every demand did not reproduce the first-come-first-served wait', 'limit',
       round(critical_wait - (SELECT max(derived_wait) FROM queue_closed_form WHERE discipline = 'fifo'), 12)
FROM escalation_sweep
WHERE direction = 'over' AND rate = 1.00
  AND abs(critical_wait - (SELECT max(derived_wait) FROM queue_closed_form WHERE discipline = 'fifo')) > 1e-9

UNION ALL
-- Failing to recognise every critical demand is worse than not sorting at all, which is the asymmetry.
SELECT 'missing every critical demand was not worse than not sorting at all', 'limit',
       round(critical_wait, 6)
FROM escalation_sweep
WHERE direction = 'under' AND rate = 1.00
  AND critical_wait <= (SELECT max(derived_wait) FROM queue_closed_form WHERE discipline = 'fifo')

UNION ALL
-- So a crossing exists, and it has to be a single crossing or the published rate means nothing.
SELECT 'the crossing into worse-than-no-priority is not a single crossing', 'crossings', n
FROM (
    SELECT count(*) AS n FROM (
        SELECT worse, lag(worse) OVER (ORDER BY rate) AS previous
        FROM (
            -- Recomputed from the two waits rather than read out of the stored flag.
            SELECT under_recognition_rate AS rate,
                   critical_wait > wait_with_no_priority_at_all AS worse
            FROM escalation_crossover
        )
    ) WHERE previous IS NOT NULL AND worse <> previous
) WHERE n <> 1

UNION ALL
SELECT 'the critical wait is not monotone in the under-recognition rate', 'rate ' || under_recognition_rate,
       round(critical_wait, 6)
FROM (
    SELECT under_recognition_rate, critical_wait,
           lag(critical_wait) OVER (ORDER BY under_recognition_rate) AS previous
    FROM escalation_crossover
)
WHERE previous IS NOT NULL AND critical_wait <= previous

UNION ALL
-- The handling-time sweep. The order swaps exactly where the algebra says it does, which is the whole
-- content of the rule: at urgency_1 * handling_2 / urgency_2 days, and nowhere else.
SELECT 'the order swapped on the wrong side of the derived threshold',
       'handling ' || critical_handling_days,
       round(weighted_critical_first / weighted_standard_first, 6)
FROM urgency_sweep
WHERE (critical_handling_days < handling_at_which_the_order_swaps
       AND weighted_critical_first >= weighted_standard_first)
   OR (critical_handling_days > handling_at_which_the_order_swaps
       AND weighted_critical_first <= weighted_standard_first)

UNION ALL
-- The threshold cannot depend on the thing being swept.
SELECT 'the swap threshold moved with the swept handling time', 'threshold',
       round(spread, 15)
FROM (
    SELECT max(handling_at_which_the_order_swaps) - min(handling_at_which_the_order_swaps) AS spread
    FROM urgency_sweep
)
WHERE spread > 1e-12

UNION ALL
-- And the sweep has to bracket the threshold, or nothing above was tested.
SELECT 'the handling sweep does not bracket its own threshold', 'bracket', 0
WHERE NOT (
    EXISTS (SELECT 1 FROM urgency_sweep WHERE weighted_critical_first < weighted_standard_first)
    AND EXISTS (SELECT 1 FROM urgency_sweep WHERE weighted_critical_first > weighted_standard_first)
)

UNION ALL
-- The two levers a prioritisation review can pull, in the order they are worth pulling.
SELECT 'triage quality came out cheaper than order refinement, so the prescription is backwards',
       'levers', round((weighted_real / weighted_perfect) / cost_of_the_next_best_order, 4)
FROM triage_cost
WHERE weighted_real / weighted_perfect <= cost_of_the_next_best_order

UNION ALL
SELECT 'the critical class does not feel imperfect triage more than the aggregate does', 'ratio',
       round(c.simulated_wait / c.derived_under_perfect_triage
             / (t.weighted_real / t.weighted_perfect), 4)
FROM triage_cost t, triage_closed_form c
WHERE c.priority = 'p1'
  AND c.derived_wait / c.derived_under_perfect_triage <= t.weighted_real / t.weighted_perfect;
