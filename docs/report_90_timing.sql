-- The speed measures that survive censoring, and the one that usually does not exist.
--
-- `half_life` is the day by which half of the eventual conversions have happened. It is defined at every
-- stage. `median` is the day by which half of *everybody* has converted, and it exists only where more
-- than half of them ever do - which is eight of the twenty-two stages here.
SELECT
    funnel,
    step,
    stage,
    round(plateau_incidence, 4)                       AS eventually_convert,
    round(half_life_days, 3)                          AS half_life_days,
    coalesce(round(median_days, 2)::VARCHAR, 'none')   AS median_days
FROM survival_readings
WHERE step > 1
ORDER BY position, step;
