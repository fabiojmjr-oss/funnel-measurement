-- The effort a sequential desk spends, per class. The rarest class is the most expensive to confirm,
-- because the prior is against it - and it is also the slowest to handle and the least accurately labelled.
SELECT
    l.rule,
    l.stop_threshold                            AS threshold,
    l.priority,
    round(l.mean_looks, 4)                      AS mean_looks,
    round(l.variance_looks, 4)                  AS variance_of_looks,
    l.most_looks_taken                          AS most_looks_taken,
    round(l.correctly_labelled, 4)              AS correctly_labelled
FROM sequential_looks l
WHERE l.rule = 'cost'
ORDER BY l.stop_threshold, l.true_rank;

-- And what the two objectives produce from the same walk: the cost-aware rule gets fewer labels right and
-- less waiting.
SELECT
    stop_threshold                              AS threshold,
    rule,
    round(mean_looks_per_demand, 4)             AS mean_looks,
    round(utilisation, 4)                       AS utilisation,
    round(labels_correct, 4)                    AS labels_correct,
    round(critical_correct, 4)                  AS critical_correct,
    round(critical_wait, 4)                     AS critical_wait,
    round(weighted_waiting, 4)                  AS cost_at_declared_urgency,
    round(against_best_constant_effort, 4)      AS against_one_fixed_look,
    is_best_threshold                           AS best
FROM sequential_cost
ORDER BY stop_threshold, rule;
