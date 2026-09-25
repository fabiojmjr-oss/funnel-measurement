-- The best stopping rule against wave 7's best constant effort, at every utilisation swept. The sequential
-- rule never wins, which is the opposite of what the wave was built to show.
SELECT
    base_utilisation                            AS utilisation_before_triage,
    rule,
    best_threshold,
    best_constant_looks                         AS constant_looks,
    round(stopping_cost, 4)                     AS stopping_cost,
    round(constant_cost, 4)                     AS constant_cost,
    round(stopping_over_constant, 4)            AS stopping_over_constant,
    stopping_wins
FROM stopping_versus_constant
ORDER BY rule, base_utilisation;

-- What the spread of the effort costs on its own: real in direction, negligible in size here, because a
-- look is a small fraction of a handling time.
SELECT
    stop_threshold                              AS threshold,
    round(mean_looks_per_demand, 4)             AS mean_looks,
    round(residual_work, 6)                     AS residual_work,
    round(residual_work_if_no_spread, 6)        AS residual_work_if_effort_were_fixed,
    round(residual_work / residual_work_if_no_spread, 6) AS cost_of_the_spread
FROM sequential_capacity
WHERE rule = 'cost'
ORDER BY stop_threshold;
