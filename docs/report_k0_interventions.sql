-- Six changes shipped on the same day, and what each one actually did - measured against the world where it
-- was not shipped, on the same subjects, with the same coins. No operation has this column.
SELECT
    funnel,
    kind,
    target_step,
    rate_multiplier,
    lag_multiplier,
    subjects,
    round(counterfactual_rate, 4)   AS rate_if_not_shipped,
    round(actual_rate, 4)           AS rate_as_shipped,
    round(causal_lift, 4)           AS causal_lift,
    round(declared_lift, 4)         AS declared_lift,
    subjects_gained,
    subjects_lost,
    round(tolerance, 4)             AS tolerance
FROM lift_eventual
ORDER BY position;

-- The before-and-after comparison a dashboard makes: the thirty days of conversions before the change
-- against the thirty days after it, with no counterfactual anywhere in it. The two changes that raised a
-- real conversion rate are the two that look like they did nothing, and the change with no effect on
-- conversion at all is the largest apparent win on the page.
SELECT
    funnel,
    kind,
    round(window_rate_before, 4)    AS window_rate_before,
    round(window_rate_after, 4)     AS window_rate_after,
    round(window_lift, 4)           AS window_lift,
    round(declared_lift, 4)         AS true_lift,
    CASE WHEN declared_lift > 0 THEN round(declared_lift / window_lift, 2) END AS true_over_window
FROM lift_windows
ORDER BY window_lift DESC;
