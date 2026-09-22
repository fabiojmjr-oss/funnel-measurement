-- The two directions a triage desk can be wrong in, swept one at a time. The last column is what wave 5
-- says nothing in this table can move.
SELECT
    direction,
    rate,
    round(top_label_utilisation, 4)     AS top_label_utilisation,
    round(critical_wait, 4)             AS critical_wait,
    round(critical_ratio, 4)            AS critical_against_perfect_triage,
    round(standard_wait, 4)             AS standard_wait,
    round(improvement_wait, 4)          AS improvement_wait,
    round(weighted_waiting, 4)          AS weighted_waiting,
    round(work_weighted_waiting, 10)    AS work_weighted_waiting
FROM escalation_sweep
ORDER BY direction, rate;

-- And the rate past which sorting the queue is worse for the critical class than not sorting it.
SELECT
    under_recognition_rate,
    round(critical_wait, 4)                 AS critical_wait,
    round(wait_with_no_priority_at_all, 4)  AS wait_with_no_priority_at_all,
    round(critical_over_no_priority, 4)     AS ratio,
    worse_than_no_priority
FROM escalation_crossover
WHERE under_recognition_rate IN (0.00, 0.20, 0.40, 0.55, 0.60, 0.61, 0.62, 0.65, 0.80, 1.00)
ORDER BY under_recognition_rate;
