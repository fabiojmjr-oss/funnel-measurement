-- Every order the queue could be served in, what each one truly costs, and what the dashboard would say
-- about it. The two columns rank the six orders in exactly opposite directions.
SELECT
    ordering,
    round(weighted_waiting, 4)          AS cost_at_declared_urgency,
    round(weighted_against_best, 4)     AS against_the_best_order,
    round(mean_wait_per_demand, 4)      AS reported_mean_wait,
    round(work_weighted_waiting, 10)    AS work_weighted_waiting
FROM urgency_orders
ORDER BY weighted_waiting;

-- The rule that names the winner without trying the six, and how much margin it has.
SELECT
    label                                       AS demand_class,
    declared_rank,
    rule_rank,
    urgency_weight,
    round(realised_service_mean, 4)             AS mean_handling_days,
    round(cost_per_day_of_handling, 4)          AS urgency_per_day_of_handling,
    next_priority                               AS against,
    round(declared_urgency_ratio, 4)            AS urgency_ratio,
    round(handling_time_ratio, 4)               AS handling_ratio,
    round(margin_before_the_order_swaps, 4)     AS margin
FROM urgency_rule
ORDER BY rule_rank;
