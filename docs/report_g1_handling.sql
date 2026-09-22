-- The critical class's handling time swept at constant workload: the same critical work arriving as many
-- quick incidents or as a few slow ones. Past the derived threshold, critical-first is the wrong order.
SELECT
    round(critical_handling_days, 4)                    AS critical_handling_days,
    round(critical_arrival_rate, 4)                     AS critical_arrivals_per_day,
    round(critical_cost_per_day_of_handling, 4)          AS critical_urgency_per_day,
    round(standard_cost_per_day_of_handling, 4)          AS standard_urgency_per_day,
    round(critical_wait_critical_first, 4)              AS critical_wait_if_first,
    round(critical_wait_standard_first, 4)              AS critical_wait_if_second,
    round(critical_first_over_standard_first, 4)         AS cost_of_critical_first,
    round(handling_at_which_the_order_swaps, 4)          AS threshold
FROM urgency_sweep
ORDER BY critical_handling_days;

-- The two levers a prioritisation review can pull, on one scale.
SELECT
    round(weighted_perfect, 4)                                  AS cost_with_perfect_triage,
    round(weighted_real, 4)                                     AS cost_with_this_triage_desk,
    round(cost_of_imperfect_triage, 4)                          AS cost_of_imperfect_triage,
    round(cost_of_the_next_best_order, 4)                       AS cost_of_the_next_best_order,
    round(cost_of_the_worst_order, 4)                           AS cost_of_the_worst_order,
    round(cost_of_imperfect_triage_to_the_critical_class, 4)     AS what_the_critical_class_feels
FROM triage_cost;
