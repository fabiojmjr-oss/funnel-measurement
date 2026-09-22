-- What each queue discipline does to each class, and what it does to the two totals.
SELECT
    d.discipline,
    d.label                                  AS demand_class,
    d.demands,
    round(d.mean_wait, 4)                    AS mean_wait_days,
    round(d.wait_standard_error, 4)          AS clustered_standard_error,
    round(d.mean_sojourn, 4)                 AS mean_days_to_resolution,
    d.sla_days                               AS target_days,
    round(d.sla_met, 4)                      AS target_met,
    round(d.sla_met_without_waiting, 4)      AS target_met_if_nothing_waited
FROM queue_readings d
ORDER BY d.discipline, d.declared_rank;
