-- The same subjects read twice: once on the monotone log that assumes a stage is a partition, and once on
-- the log where subjects skip a stage, fall back to the previous one and come back weeks later. The forward
-- coins are identical in both, so every difference is a movement.
SELECT
    funnel,
    step,
    stage,
    subjects,
    monotone_reached,
    messy_reached,
    round(monotone_rate, 4)             AS monotone_rate,
    round(messy_rate, 4)                AS messy_rate,
    round(declared_rate, 4)             AS declared_ceiling,
    round(monotone_over_ceiling, 4)     AS monotone_over_ceiling,
    round(messy_over_ceiling, 4)        AS messy_over_ceiling
FROM movement_reach
ORDER BY position, step;

-- What a monotone staircase cannot hold. The messy log is a quarter larger than the monotone one on the
-- same subjects, and the extra rows are not noise: they are second entries, returns from a fallback, and
-- stages visited more than once.
SELECT
    messy_events,
    monotone_events,
    round(events_ratio, 4)              AS messy_over_monotone,
    second_entry_events,
    after_fallback_events,
    stages_visited_twice,
    subjects_that_skipped,
    subjects_that_fell_back,
    subjects_that_returned
FROM movement_dropped;
