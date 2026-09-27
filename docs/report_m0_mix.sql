-- Three origins, each of which got better at converting, and a total that got worse.
--
-- Both periods are halves of the mature horizon, so every cohort in them had the full maturity window to
-- convert. The censoring of wave 1 is already handled; what follows is a second mechanism entirely.
SELECT
    segment                                 AS origin,
    period,
    subjects,
    converted,
    round(segment_rate, 4)                  AS rate,
    round(segment_share, 4)                 AS share_of_arrivals,
    round(rate_tolerance, 4)                AS four_standard_errors
FROM mix_reading
WHERE scope = 'todos'
ORDER BY period_position, segment_position;

-- And the one number a dashboard shows.
SELECT
    period,
    subjects,
    converted,
    round(aggregate_rate, 4)                AS aggregate_rate,
    round(rate_tolerance, 4)                AS four_standard_errors
FROM mix_aggregate
WHERE scope = 'todos'
ORDER BY period_position;

-- The same reversal in the declared parameters, with no sampling in it at all. The composition of a
-- period is the arrival-weighted average of the daily shares, not the share at its midpoint, because
-- arrivals grow - which is wave 1's mechanism reappearing inside the weights.
SELECT
    period,
    segment                                 AS origin,
    round(declared_share, 4)                AS declared_share,
    round(declared_multiplier, 4)           AS declared_multiplier,
    round(declared_aggregate, 6)            AS declared_aggregate
FROM mix_declared
ORDER BY period_position, segment_position;
