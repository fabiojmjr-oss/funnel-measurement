-- The trade. More looks buy accuracy and buy utilisation, and only one of those two is worth having.
SELECT
    c.looks                                     AS looks_per_demand,
    c.tie_break,
    round(c.triage_days_per_demand, 4)          AS triage_days,
    round(c.utilisation, 4)                     AS utilisation,
    round(c.critical_accuracy, 4)               AS critico_correct,
    round(c.improvement_accuracy, 4)            AS melhoria_correct,
    round(c.critical_wait, 4)                   AS critico_wait,
    round(c.improvement_wait, 4)                AS melhoria_wait,
    round(c.weighted_waiting, 4)                AS cost_at_declared_urgency,
    round(c.against_no_triage, 4)               AS against_no_triage,
    c.is_best_effort                            AS best
FROM effort_cost c
ORDER BY c.tie_break, c.looks;

-- And what the effort costs the server on its own, with no priority order at all.
SELECT
    looks                                       AS looks_per_demand,
    round(triage_days_per_demand, 4)            AS triage_days,
    round(utilisation, 4)                       AS utilisation,
    round(wait_without_priority, 4)             AS wait_with_no_priority
FROM effort_capacity
ORDER BY looks;
