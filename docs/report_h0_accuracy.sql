-- What each level of triage effort buys, per class, under each tie-break rule. Accuracy is not monotone in
-- effort: an even number of looks produces ties, and the tie-break transfers accuracy between classes
-- rather than creating it.
SELECT
    looks                                       AS looks_per_demand,
    tie_break,
    round(max(probability) FILTER (WHERE true_priority = 'p1'), 4) AS critico_correct,
    round(max(probability) FILTER (WHERE true_priority = 'p2'), 4) AS padrao_correct,
    round(max(probability) FILTER (WHERE true_priority = 'p3'), 4) AS melhoria_correct
FROM effort_confusion
WHERE true_priority = assigned_priority
GROUP BY 1, 2
ORDER BY tie_break, looks;

-- The derivation against a draw from the declared generator, at the declared effort.
SELECT
    d.tie_break,
    d.true_priority,
    d.assigned_priority,
    round(c.probability, 6)                     AS derived,
    round(d.drawn_probability, 6)               AS drawn,
    d.demands
FROM effort_confusion_draw d
JOIN effort_confusion c
  ON c.looks = (SELECT value FROM queue_effort WHERE key = 'declared_looks')::INTEGER
 AND c.tie_break = d.tie_break AND c.true_priority = d.true_priority
 AND c.assigned_priority = d.assigned_priority
ORDER BY d.tie_break, d.true_rank, d.assigned_rank;
