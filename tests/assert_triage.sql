-- The triage desk, and the thing it cannot change.
--
-- The load-bearing claim of this wave is the one it inherits: relabelling the queue cannot alter how much
-- work is in it, so wave 5's invariance has to survive a desk that mislabels a third of its calls. If it
-- does, every extra day the critical class waits is a day some other class does not, and a triage error is a
-- transfer rather than a loss. That is asserted at a relative 1e-12, not at a tolerance.
--
-- The recursion in sql/a0_triage.sql is a second, independent implementation of the one in sql/90_queue.sql,
-- and the assertions below are what makes that duplication safe rather than merely repeated: the two have to
-- agree on every quantity they share.
SELECT 'a busy period of the triage simulation ends at a different instant from wave 5' AS failure,
       'period ' || busy_period AS detail,
       round(gap, 12) AS value
FROM (
    SELECT t.busy_period, abs(max(t.depart) - max(q.depart)) AS gap
    FROM (SELECT busy_period, depart FROM triage_waits) t
    JOIN (SELECT busy_period, depart FROM queue_periods) q ON q.busy_period = t.busy_period
    GROUP BY t.busy_period
)
WHERE gap > 1e-6

UNION ALL
SELECT 'a triage busy period is not as long as the work in it', 'period ' || busy_period,
       round(span - work, 12)
FROM (
    SELECT busy_period, max(depart) - min(arrival) AS span, sum(service) AS work
    FROM triage_waits GROUP BY 1
)
WHERE abs(span - work) > 1e-6

UNION ALL
-- The invariance, surviving the relabelling.
-- Recomputed from the two primitive columns rather than read out of `ratio_to_perfect_triage`. Defect 9 was
-- an assertion that trusted a stored ratio; defect 11 is that I wrote five more of them in this wave, one
-- wave after recording it.
SELECT 'the work-weighted waiting changed when the labels did', 'total',
       round(abs(t.work_weighted_wait / q.work_weighted_wait - 1.0), 15)
FROM triage_totals t, queue_totals q
WHERE q.discipline = 'priority'
  AND abs(t.work_weighted_wait / q.work_weighted_wait - 1.0) > 1e-12

UNION ALL
-- The residual work is a property of the demands, not of the labels, so it cannot move either.
SELECT 'the residual work changed when the labels did', 'W0',
       round(t.residual_work - q.residual_work, 15)
FROM triage_residual t, queue_residual q
WHERE abs(t.residual_work - q.residual_work) > 1e-12
   OR abs(t.utilisation - q.utilisation) > 1e-12

UNION ALL
-- The declared matrix, and the draw against it.
SELECT 'a row of the triage matrix does not sum to one', true_priority, round(total - 1.0, 15)
FROM (SELECT true_priority, sum(probability) AS total FROM queue_triage GROUP BY 1)
WHERE abs(total - 1.0) > 1e-12

UNION ALL
SELECT 'a realised triage probability is more than four standard errors from the declared one',
       t.true_priority || ' to ' || t.assigned_priority, round(realised - t.probability, 6)
FROM queue_triage t
JOIN (
    SELECT true_priority, assigned_priority,
           count(*) AS n,
           count(*) / sum(count(*)) OVER (PARTITION BY true_priority) AS realised,
           sum(count(*)) OVER (PARTITION BY true_priority) AS from_class
    FROM triage_assignment GROUP BY 1, 2
) r ON r.true_priority = t.true_priority AND r.assigned_priority = t.assigned_priority
WHERE abs(r.realised - t.probability)
      > 4.0 * sqrt(t.probability * (1.0 - t.probability) / r.from_class)

UNION ALL
-- Structure.
SELECT 'a demand was served before it arrived', job_id::VARCHAR, round(wait, 12)
FROM triage_waits WHERE wait < -1e-9
UNION ALL
SELECT 'a demand was not served exactly once by the triage simulation', job_id::VARCHAR, n
FROM (SELECT job_id, count(*) AS n FROM triage_waits GROUP BY 1) WHERE n <> 1
UNION ALL
SELECT 'the triage simulation lost or gained demands', 'count',
       abs((SELECT count(*) FROM triage_waits) - (SELECT count(*) FROM queue_demands))::DOUBLE
WHERE (SELECT count(*) FROM triage_waits) <> (SELECT count(*) FROM queue_demands)
UNION ALL
SELECT 'a demand changed its true class when it was relabelled', job_id::VARCHAR, 0
FROM triage_waits t JOIN queue_demands d USING (job_id) WHERE t.true_priority <> d.priority
UNION ALL
SELECT 'a demand changed its handling time when it was relabelled', job_id::VARCHAR,
       round(t.service - d.service, 12)
FROM triage_waits t JOIN queue_demands d USING (job_id) WHERE abs(t.service - d.service) > 1e-12

UNION ALL
-- The finding about the label itself. If the top label were mostly genuine there would be no wave here.
SELECT 'the top label is mostly genuine, so escalation inflation is not wired up', assigned_priority,
       round(share_correctly_labelled, 4)
FROM triage_purity WHERE assigned_priority = 'p1' AND share_correctly_labelled >= 0.5

UNION ALL
-- The top label has to have swollen beyond the class it names.
SELECT 'the top label did not swell beyond its own class', 'p1',
       round(p.share_of_all_demands, 4)
FROM triage_purity p, queue_moments m
WHERE p.assigned_priority = 'p1' AND m.priority = 'p1'
  AND p.share_of_all_demands <= m.realised_share

UNION ALL
-- The damage, in sign. Triage errors move waiting from the classes that were being protected to the class
-- that was not, so the top two have to be worse off and the bottom one better off. A table where everybody
-- lost would mean the invariance had been broken somewhere.
SELECT 'a protected class was not made worse off by imperfect triage', priority,
       round(wait_under_real_triage / wait_under_perfect_triage, 4)
FROM triage_damage WHERE rnk <= 2 AND wait_under_real_triage <= wait_under_perfect_triage
UNION ALL
SELECT 'the unprotected class was not made better off by imperfect triage', priority,
       round(wait_under_real_triage / wait_under_perfect_triage, 4)
FROM triage_damage WHERE rnk = 3 AND wait_under_real_triage >= wait_under_perfect_triage

UNION ALL
-- Imperfect triage still has to beat no priority at all for the critical class, at the declared rates.
SELECT 'imperfect triage is already worse than no priority for this class', priority,
       round(wait_under_real_triage / wait_under_no_priority, 4)
FROM triage_damage WHERE rnk = 1 AND wait_under_real_triage >= wait_under_no_priority

UNION ALL
-- And the sting. The metric a service desk reports gets *better* as the triage desk gets worse, because
-- over-escalation moves the cheap and numerous demands to the front. If it did not, the wave's sharpest
-- sentence would be wrong.
SELECT 'the reported mean wait did not improve when triage degraded', 'per-demand mean',
       round(t.mean_wait_per_demand / q.mean_wait_per_demand, 4)
FROM triage_totals t, queue_totals q
WHERE q.discipline = 'priority' AND t.mean_wait_per_demand >= q.mean_wait_per_demand;
