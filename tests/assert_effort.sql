-- What triage costs, and the two things about it that are exact.
--
-- The confusion matrix of this wave is not declared, it is derived: a finite sum over the compositions of
-- `looks` votes into three classes. So the first assertions are about the arithmetic being arithmetic -
-- every row of every matrix summing to one at machine precision, and the derivation agreeing with a draw
-- from the declared generator. The second are about the finding, which is that neither accuracy nor cost is
-- monotone in effort.
SELECT 'a row of a derived confusion matrix does not sum to one' AS failure,
       looks || ' looks, ' || tie_break || ', ' || true_priority AS detail,
       round(total - 1.0, 15) AS value
FROM (
    SELECT looks, tie_break, true_priority, sum(probability) AS total
    FROM effort_confusion GROUP BY 1, 2, 3
)
WHERE abs(total - 1.0) > 1e-12

UNION ALL
-- One look cannot tie, so both tie-breaks have to give the identical matrix. If they differ, the tie-break
-- is being applied where there is no tie.
SELECT 'the two tie-breaks differ at one look, where no tie is possible', true_priority || ' to ' || assigned_priority,
       round(spread, 15)
FROM (
    SELECT true_priority, assigned_priority, max(probability) - min(probability) AS spread
    FROM effort_confusion WHERE looks = 1 GROUP BY 1, 2
)
WHERE spread > 1e-12

UNION ALL
-- With no looks there is no information, so every demand carries the same label and the queue is one queue.
SELECT 'zero looks did not collapse into a single label', tie_break, n
FROM (
    SELECT tie_break, count(DISTINCT assigned_priority)::DOUBLE AS n
    FROM effort_confusion WHERE looks = 0 GROUP BY 1
)
WHERE n <> 1

UNION ALL
SELECT 'zero looks did not reproduce the first-come-first-served wait', tie_break,
       round(critical_wait - (SELECT wait_without_priority FROM effort_capacity WHERE looks = 0), 9)
FROM effort_cost
WHERE looks = 0
  AND abs(critical_wait - (SELECT wait_without_priority FROM effort_capacity WHERE looks = 0)) > 1e-9

UNION ALL
-- The two tie-breaks are mirror images: what one gives the top class the other gives the bottom one. This
-- is the sharpest available statement that the tie-break transfers accuracy rather than creating it.
SELECT 'the tie-breaks are not mirror images of each other', 'looks ' || u.looks,
       round(u.probability - l.probability, 15)
FROM effort_confusion u
JOIN queue_classes ut ON ut.priority = u.true_priority
JOIN queue_classes ua ON ua.priority = u.assigned_priority
JOIN queue_classes lt ON lt.rnk = 4 - ut.rnk
JOIN queue_classes la ON la.rnk = 4 - ua.rnk
JOIN effort_confusion l
  ON l.looks = u.looks AND l.tie_break = 'lenient'
 AND l.true_priority = lt.priority AND l.assigned_priority = la.priority
WHERE u.tie_break = 'urgent' AND abs(u.probability - l.probability) > 1e-12

UNION ALL
-- The derivation against the draw, at the declared effort, at four standard errors of a binomial computed
-- from the number of demands of that true class.
SELECT 'a derived confusion probability is more than four standard errors from the drawn one',
       d.tie_break || ' ' || d.true_priority || ' to ' || d.assigned_priority,
       round(d.drawn_probability - c.probability, 6)
FROM effort_confusion_draw d
JOIN effort_confusion c
  ON c.looks = (SELECT value FROM queue_effort WHERE key = 'declared_looks')::INTEGER
 AND c.tie_break = d.tie_break AND c.true_priority = d.true_priority
 AND c.assigned_priority = d.assigned_priority
JOIN (
    SELECT tie_break, true_priority, sum(demands) AS from_class
    FROM effort_confusion_draw GROUP BY 1, 2
) n ON n.tie_break = d.tie_break AND n.true_priority = d.true_priority
WHERE abs(d.drawn_probability - c.probability)
      > 4.0 * sqrt(c.probability * (1.0 - c.probability) / n.from_class)

UNION ALL
-- Accuracy is not monotone in effort, and the assertion is that it is not. Two looks under the urgent
-- tie-break have to leave the bottom class *worse* than one look, or the parity result is not there.
SELECT 'two looks did not leave the bottom class worse off than one look', 'accuracy',
       round(two.probability - one.probability, 6)
FROM effort_confusion one, effort_confusion two
WHERE one.looks = 1 AND one.tie_break = 'urgent' AND one.true_priority = 'p3' AND one.assigned_priority = 'p3'
  AND two.looks = 2 AND two.tie_break = 'urgent' AND two.true_priority = 'p3' AND two.assigned_priority = 'p3'
  AND two.probability >= one.probability

UNION ALL
-- And an even look after an odd one has to buy the tie-break's victim nothing at all.
SELECT 'the fourth look bought the bottom class something', 'accuracy',
       round(four.probability - three.probability, 15)
FROM effort_confusion three, effort_confusion four
WHERE three.looks = 3 AND three.tie_break = 'urgent' AND three.true_priority = 'p3' AND three.assigned_priority = 'p3'
  AND four.looks = 4 AND four.tie_break = 'urgent' AND four.true_priority = 'p3' AND four.assigned_priority = 'p3'
  AND abs(four.probability - three.probability) > 1e-12

UNION ALL
-- Capacity. Every look has to cost the declared time, exactly, and utilisation has to rise with effort.
SELECT 'the triage time per demand is not the declared cost per look', 'looks ' || looks,
       round(triage_days_per_demand - looks * (SELECT value FROM queue_effort WHERE key = 'look_days'), 15)
FROM effort_capacity
WHERE abs(triage_days_per_demand - looks * (SELECT value FROM queue_effort WHERE key = 'look_days')) > 1e-12

UNION ALL
SELECT 'utilisation did not rise with triage effort', 'looks ' || looks, round(utilisation, 6)
FROM (
    SELECT looks, utilisation, lag(utilisation) OVER (ORDER BY looks) AS previous FROM effort_capacity
)
WHERE previous IS NOT NULL AND utilisation <= previous

UNION ALL
SELECT 'the swept utilisation is out of steady state at a point reported as feasible',
       'utilisation ' || base_utilisation || ' at ' || looks || ' looks', round(utilisation_with_triage, 6)
FROM effort_sweep WHERE NOT infeasible AND utilisation_with_triage >= 1.0

UNION ALL
-- The finding. Spending more than the optimum has to cost, and spending a lot has to cost a lot.
SELECT 'the optimum is not interior, so there is no trade to report', 'best effort',
       best_looks::DOUBLE
FROM effort_optimum
WHERE base_utilisation = 0.78 AND tie_break = 'urgent'
  AND (best_looks = 0 OR best_looks = (SELECT max(looks) FROM effort_cost))

UNION ALL
SELECT 'the declared effort is not past the optimum, so the declared scenario hides the finding', 'declared',
       round(declared.weighted_waiting / best.weighted_waiting, 4)
FROM effort_cost declared, effort_cost best
WHERE declared.tie_break = 'urgent'
  AND declared.looks = (SELECT value FROM queue_effort WHERE key = 'declared_looks')::INTEGER
  AND best.tie_break = 'urgent' AND best.is_best_effort
  AND declared.weighted_waiting <= best.weighted_waiting

UNION ALL
SELECT 'spending past the optimum did not eventually cost more than not triaging at all', 'looks',
       round(min(against_no_triage), 4)
FROM effort_cost WHERE tie_break = 'urgent' AND looks >= 3
HAVING min(against_no_triage) <= 1.0

UNION ALL
-- The class the triage exists to protect has to be worse off at the largest effort than at the smallest,
-- or the wave's fourth result is wrong.
SELECT 'the critical class was not eventually harmed by more triage', 'critical wait',
       round(most.critical_wait - least.critical_wait, 6)
FROM effort_cost least, effort_cost most
WHERE least.tie_break = 'urgent' AND least.looks = 1
  AND most.tie_break = 'urgent' AND most.looks = (SELECT max(looks) FROM effort_cost)
  AND most.critical_wait <= least.critical_wait

UNION ALL
-- And the prescription: the effort worth spending has to fall as the desk fills up, and reach zero.
SELECT 'the best effort did not fall to zero at high utilisation', 'sweep', 0
WHERE NOT EXISTS (
    SELECT 1 FROM effort_optimum WHERE tie_break = 'urgent' AND best_looks = 0
)
UNION ALL
SELECT 'triage still pays at the highest swept utilisation, so there is no crossover', 'sweep',
       round(against_no_triage, 4)
FROM effort_optimum
WHERE tie_break = 'urgent' AND base_utilisation = (SELECT max(base_utilisation) FROM effort_optimum)
  AND against_no_triage < 1.0

UNION ALL
SELECT 'the best effort is not weakly decreasing in utilisation', 'utilisation ' || base_utilisation,
       best_looks::DOUBLE
FROM (
    SELECT base_utilisation, best_looks,
           lag(best_looks) OVER (PARTITION BY tie_break ORDER BY base_utilisation) AS previous
    FROM effort_optimum WHERE tie_break = 'urgent'
)
WHERE previous IS NOT NULL AND best_looks > previous

UNION ALL
-- The number of looks the desk could even perform has to collapse as it fills up.
SELECT 'the feasible effort did not collapse with utilisation', 'utilisation ' || base_utilisation,
       most_looks_feasible::DOUBLE
FROM (
    SELECT base_utilisation, most_looks_feasible,
           lag(most_looks_feasible) OVER (PARTITION BY tie_break ORDER BY base_utilisation) AS previous
    FROM effort_optimum WHERE tie_break = 'urgent'
)
WHERE previous IS NOT NULL AND most_looks_feasible > previous;
