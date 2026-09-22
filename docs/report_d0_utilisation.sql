-- Waiting against utilisation, and what one more percent of demand is worth at each level. No discipline
-- changes any row of this table.
SELECT
    utilisation,
    round(mean_wait_per_day_of_work, 4)             AS simulated_wait,
    round(derived_wait, 4)                          AS derived_wait,
    round(mean_wait_per_day_of_work / derived_wait, 4) AS simulated_over_derived,
    round(elasticity_of_waiting_in_demand, 3)       AS percent_of_waiting_per_percent_of_demand
FROM queue_sweep_closed_form
WHERE discipline = 'fifo'
ORDER BY utilisation;
