-- The denominator is not the number of subjects, and the bias has no sign.
--
-- A re-entry adds a second row at the entry stage, a fallback adds a second row at a middle stage. A funnel
-- read by counting rows therefore inflates both ends of every fraction, by different factors, and which one
-- wins depends on where in the funnel subjects gave up. There is no correction factor to apply.
SELECT
    funnel,
    step,
    stage,
    events,
    subjects,
    round(events_per_subject, 4)        AS events_per_subject,
    round(event_counted_rate, 4)        AS event_counted_rate,
    round(subject_counted_rate, 4)      AS subject_counted_rate,
    round(event_over_subject, 4)        AS event_over_subject
FROM movement_event_counted
ORDER BY position, step;

-- "Time to reach stage k" is two numbers whenever a stage can be visited twice, and nothing in the schema
-- says which one a report meant.
SELECT
    funnel,
    step,
    stage,
    subjects,
    round(mean_first_touch, 2)          AS mean_first_touch,
    round(mean_last_touch, 2)           AS mean_last_touch,
    round(gap_days, 2)                  AS gap_days,
    round(share_visited_twice, 4)       AS share_visited_twice
FROM movement_timing
ORDER BY position, step;
