-- The desk that decides how hard to look, and the result I did not expect.
--
-- The walk is a probability distribution over stopping states, so the first assertions are that it is one:
-- every threshold and every true class has to account for exactly all of the probability, at machine
-- precision. Then the findings, and the last of them is asserted against my own prediction rather than for
-- it - the stopping rule never beats wave 7's single fixed look, and the assertion says so.
SELECT 'the stopping walk does not account for all the probability' AS failure,
       stop_threshold || ', class ' || true_rank AS detail,
       round(mass - 1.0, 15) AS value
FROM (
    SELECT stop_threshold, true_rank, sum(reach) AS mass FROM sequential_walk GROUP BY 1, 2
)
WHERE abs(mass - 1.0) > 1e-9

UNION ALL
SELECT 'a confusion row of the stopping rule does not sum to one',
       rule || ' ' || stop_threshold || ' ' || true_priority, round(total - 1.0, 15)
FROM (
    SELECT rule, stop_threshold, true_priority, sum(probability) AS total
    FROM sequential_confusion GROUP BY 1, 2, 3
)
WHERE abs(total - 1.0) > 1e-9

UNION ALL
-- Every state kept is a stopped state, and no stopped state was expanded. That is what makes the walk a
-- partition rather than a coincidence of two identical predicates.
SELECT 'a state in the walk is not a stopped state', 'walk', count(*)::DOUBLE
FROM sequential_walk WHERE NOT stopped
HAVING count(*) > 0

UNION ALL
-- The declared prior shares are distinct, so no two posteriors can coincide and the tie-break of wave 7 is
-- never reached. If it ever is, the labelling is no longer determined by the model alone.
SELECT 'the stopping rule needed a tie-break', 'ties', count(*)::DOUBLE
FROM sequential_outcomes WHERE needed_a_tie_break
HAVING count(*) > 0

UNION ALL
-- The lowest threshold is at or below the largest prior share, so the desk commits before looking and the
-- queue is one queue. That is how "do not triage" sits inside this family rather than beside it.
SELECT 'the lowest threshold did not stop before the first look', 'looks',
       round(max(mean_looks), 12)
FROM sequential_looks
WHERE stop_threshold = (SELECT min(stop_threshold) FROM queue_thresholds)
HAVING max(mean_looks) > 1e-12

UNION ALL
SELECT 'the lowest threshold did not reproduce the first-come-first-served wait', rule,
       round(critical_wait - (SELECT wait_without_priority FROM effort_capacity WHERE looks = 0), 9)
FROM sequential_cost
WHERE stop_threshold = (SELECT min(stop_threshold) FROM queue_thresholds)
  AND abs(critical_wait - (SELECT wait_without_priority FROM effort_capacity WHERE looks = 0)) > 1e-9

UNION ALL
-- Effort has to rise with the threshold, or the rule is not responding to the evidence it demands.
SELECT 'mean effort did not rise with the threshold', 'threshold ' || stop_threshold,
       round(mean_looks_per_demand, 6)
FROM (
    SELECT stop_threshold, mean_looks_per_demand,
           lag(mean_looks_per_demand) OVER (ORDER BY stop_threshold) AS previous
    FROM sequential_capacity WHERE rule = 'cost'
)
WHERE previous IS NOT NULL AND mean_looks_per_demand < previous

UNION ALL
-- Both labelling rules share the walk, so they must spend exactly the same effort. If they do not, the
-- comparison between them is not isolating the objective.
SELECT 'the two labelling rules did not spend the same effort', 'threshold ' || stop_threshold,
       round(spread, 15)
FROM (
    SELECT stop_threshold, max(mean_looks_per_demand) - min(mean_looks_per_demand) AS spread
    FROM sequential_capacity GROUP BY 1
)
WHERE spread > 1e-12

UNION ALL
-- The first finding: the rarest class is the most expensive to confirm, because the prior is against it.
SELECT 'the critical class is not the most expensive class to classify', 'threshold ' || stop_threshold,
       round(critical_looks / improvement_looks, 4)
FROM (
    SELECT stop_threshold,
           max(mean_looks) FILTER (WHERE true_rank = 1) AS critical_looks,
           max(mean_looks) FILTER (WHERE true_rank = 3) AS improvement_looks
    FROM sequential_looks WHERE rule = 'cost' GROUP BY 1
)
WHERE improvement_looks > 0 AND critical_looks <= improvement_looks

UNION ALL
-- The second finding: the accuracy-maximising rule labels the critical class *worse* than a single raw look
-- would, because Bayes shrinks it toward a base rate that is against it.
SELECT 'the accuracy rule does not under-recognise the critical class at its own optimum', 'critical',
       round(l.correctly_labelled, 4)
FROM sequential_cost c
JOIN sequential_looks l
  ON l.rule = c.rule AND l.stop_threshold = c.stop_threshold AND l.true_rank = 1
WHERE c.rule = 'accuracy' AND c.is_best_threshold
  AND l.correctly_labelled >= (SELECT value FROM queue_effort WHERE key = 'look_accuracy')

UNION ALL
-- The third: the cost-aware rule beats the accuracy rule at every threshold above the degenerate one, and
-- does it while getting fewer labels right. Both halves are asserted.
SELECT 'the cost-aware rule did not beat the accuracy rule at this threshold', 'threshold ' || a.stop_threshold,
       round(k.weighted_waiting / a.weighted_waiting, 6)
FROM sequential_cost a
JOIN sequential_cost k ON k.stop_threshold = a.stop_threshold AND k.rule = 'cost'
WHERE a.rule = 'accuracy'
  AND a.stop_threshold > (SELECT min(stop_threshold) FROM queue_thresholds)
  AND k.weighted_waiting >= a.weighted_waiting

UNION ALL
SELECT 'the cost-aware rule did not get fewer labels right at its own optimum', 'labels',
       round(k.labels_correct - a.labels_correct, 6)
FROM sequential_cost k, sequential_cost a
WHERE k.rule = 'cost' AND k.is_best_threshold
  AND a.rule = 'accuracy' AND a.stop_threshold = k.stop_threshold
  AND k.labels_correct >= a.labels_correct

UNION ALL
-- And the finding I predicted backwards, asserted as it came out: the stopping rule loses to one fixed look
-- at every utilisation swept, including the ones with plenty of slack.
SELECT 'the stopping rule beat a single fixed look somewhere, which it did not when this was written',
       rule || ' at ' || base_utilisation, round(stopping_over_constant, 4)
FROM stopping_versus_constant
WHERE stopping_wins

UNION ALL
SELECT 'the stopping rule is not losing by a margin worth reporting', 'worst margin',
       round(max(stopping_over_constant), 4)
FROM stopping_versus_constant WHERE rule = 'cost'
HAVING max(stopping_over_constant) < 1.01

UNION ALL
-- The spread of the effort is charged by the residual work, so it can only make things worse, never better.
SELECT 'the spread of the triage effort reduced the residual work', 'threshold ' || stop_threshold,
       round(residual_work / residual_work_if_no_spread, 9)
FROM sequential_capacity
WHERE residual_work < residual_work_if_no_spread - 1e-12

UNION ALL
-- And the honest calibration: here that cost is real and negligible, because a look is a small fraction of
-- a handling time. An assertion that it stays small is an assertion about this account, not about queues.
SELECT 'the cost of the effort spread is no longer negligible on this account', 'threshold ' || stop_threshold,
       round(residual_work / residual_work_if_no_spread, 6)
FROM sequential_capacity
WHERE residual_work / residual_work_if_no_spread > 1.01

UNION ALL
SELECT 'the swept utilisation is out of steady state at a point reported as feasible',
       rule || ' ' || base_utilisation || ' at ' || stop_threshold, round(utilisation_with_triage, 6)
FROM stopping_sweep WHERE NOT infeasible AND utilisation_with_triage >= 1.0;
