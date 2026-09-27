-- Why the aggregate moved, split exactly into what happened inside the origins and what happened to
-- their weights.
--
--   d(sum w*p) = sum (w0+w1)/2 * (p1-p0)  +  sum (p0+p1)/2 * (w1-w0)
--
-- The two terms add to the change with no remainder, which is why `residual` is zero rather than small.
-- The textbook split, which weights the rate change by the starting shares and the share change by the
-- starting rates, drops the cross term in the last column - a fifth of the pooled movement.
SELECT
    scope,
    round(aggregate_early, 4)                               AS rate_first_half,
    round(aggregate_late, 4)                                AS rate_second_half,
    round(aggregate_change, 6)                              AS change,
    round(within_segments, 6)                               AS within_origins,
    round(between_segments, 6)                              AS between_origins,
    round(within_segments + between_segments - aggregate_change, 15) AS residual,
    round(abs(between_segments / within_segments), 4)       AS mix_over_within,
    round(cross_term, 6)                                    AS dropped_cross_term,
    round(abs(cross_term / aggregate_change), 4)            AS dropped_share_of_change,
    round(smallest_origin_gain, 4)                          AS smallest_origin_gain
FROM mix_decomposition
ORDER BY scope_position, scope;
