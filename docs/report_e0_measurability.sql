-- What one 180-day slice of an unchanging queue can and cannot say, and the utilisation each extreme
-- reading would have been attributed to.
SELECT
    slices,
    round(mean_demands_per_slice, 1)       AS demands_per_slice,
    round(mean_of_slice_means, 4)          AS true_mean_wait,
    round(lowest_slice_mean, 4)            AS lowest_reading,
    round(highest_slice_mean, 4)           AS highest_reading,
    round(widest_pair_of_readings, 4)      AS highest_over_lowest,
    round(naive_half_width, 4)             AS interval_a_reviewer_would_draw,
    round(honest_half_width, 4)            AS interval_the_slices_actually_show,
    round(interval_understated_by, 4)      AS understated_by
FROM queue_measurability;

SELECT
    slice                                  AS reading,
    round(reported, 4)                     AS mean_wait_days,
    looks_like_utilisation                 AS attributable_to_utilisation
FROM queue_mistaken_for
ORDER BY reported;
