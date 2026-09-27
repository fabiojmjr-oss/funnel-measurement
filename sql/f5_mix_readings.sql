-- The reading that moved because the population moved.
--
-- Every figure here is a cohort reading on mature cohorts only, which is what wave 1 prescribed. The
-- censoring is therefore already handled, and whatever differs between the two periods is not the
-- window. That is the point of the wave: the mix is a second mechanism, orthogonal to the first, and
-- fixing the first does nothing at all about it.
--
-- The outcome measured is reaching the second stage within the maturity window, because that is the
-- stage the origin's multiplier acts on. Reading the last stage instead would put the whole funnel's
-- attrition between the mechanism and the measurement, and on the smaller funnels the early period would
-- carry a few dozen conversions - a sample too thin to tell a declared four percent gain from noise. The
-- mechanism is the same either way; this is where it is measurable.
--
-- Every reading is produced twice: once per funnel, and once pooled across all six under the scope
-- `todos`. The pooled scope is the headline because it is the only one with enough subjects in every
-- origin-by-period cell for the finding to be decisive rather than suggestive.

CREATE OR REPLACE TABLE mix_reading AS
WITH bounds AS (SELECT (SELECT value FROM params WHERE key = 'maturity_days') AS maturity),
reached AS (
    SELECT DISTINCT e.subject_id
    FROM segment_events e, bounds b
    WHERE e.step = 2 AND e.age_at_stage <= b.maturity
),
panel AS (
    SELECT
        d.subject_id, d.funnel, d.segment, d.segment_position,
        p.period, p.position AS period_position,
        CASE WHEN r.subject_id IS NULL THEN 0 ELSE 1 END AS converted
    FROM segment_draws d
    JOIN mix_periods_declared p ON d.cohort_day BETWEEN p.first_day AND p.last_day
    LEFT JOIN reached r ON r.subject_id = d.subject_id
),
scoped AS (
    SELECT funnel AS scope, * FROM panel
    UNION ALL
    SELECT 'todos', * FROM panel
),
cells AS (
    SELECT
        scope, segment, segment_position, period, period_position,
        count(*) AS subjects, sum(converted) AS converted
    FROM scoped GROUP BY 1, 2, 3, 4, 5
),
totals AS (SELECT scope, period, sum(subjects) AS period_subjects FROM cells GROUP BY 1, 2)
SELECT
    coalesce(f.position, 0)                      AS scope_position,
    c.scope,
    c.period,
    c.period_position,
    c.segment,
    c.segment_position,
    c.subjects,
    c.converted,
    c.converted / c.subjects::DOUBLE             AS segment_rate,
    c.subjects / t.period_subjects::DOUBLE       AS segment_share,
    t.period_subjects,
    -- Four standard errors of the change in this origin's rate between the two periods, which is the
    -- band the per-origin claim has to clear. Published here so the assertion reads it rather than
    -- recomputing it in a different form.
    4.0 * sqrt(c.converted / c.subjects::DOUBLE * (1.0 - c.converted / c.subjects::DOUBLE) / c.subjects)
                                                 AS rate_tolerance
FROM cells c
JOIN totals t ON t.scope = c.scope AND t.period = c.period
LEFT JOIN funnels f ON f.funnel = c.scope
ORDER BY scope_position, c.scope, c.period_position, c.segment_position;

-- The aggregate a dashboard shows: one number per scope per period, with the origins summed away.
CREATE OR REPLACE TABLE mix_aggregate AS
SELECT
    scope_position,
    scope,
    period,
    period_position,
    sum(converted)                               AS converted,
    sum(subjects)                                AS subjects,
    sum(converted) / sum(subjects)::DOUBLE       AS aggregate_rate,
    sum(segment_share * segment_rate)            AS weighted_rate,
    4.0 * sqrt(sum(converted) / sum(subjects)::DOUBLE
               * (1.0 - sum(converted) / sum(subjects)::DOUBLE) / sum(subjects)) AS rate_tolerance
FROM mix_reading
GROUP BY 1, 2, 3, 4
ORDER BY scope_position, scope, period_position;

-- Why the aggregate moved, decomposed exactly.
--
-- The move splits into what happened inside the origins and what happened to their weights. Writing the
-- split as
--
--   d(sum w*p) = sum (w0+w1)/2 * (p1-p0)  +  sum (p0+p1)/2 * (w1-w0)
--
-- makes it exact: the algebra collapses to sum(w1*p1) - sum(w0*p0) with no remainder, which is why the
-- assertion on it holds at machine precision rather than within a tolerance. The familiar textbook form,
-- which weights the rate change by the *starting* shares and the share change by the *starting* rates,
-- leaves the cross term sum(dw*dp) unaccounted for. That residual is published below rather than dropped,
-- because a decomposition with a leftover gets the leftover named "interaction" and then interpreted.
CREATE OR REPLACE TABLE mix_decomposition AS
WITH early AS (SELECT * FROM mix_reading WHERE period_position = 1),
late  AS (SELECT * FROM mix_reading WHERE period_position = 2),
paired AS (
    SELECT
        e.scope_position, e.scope, e.segment, e.segment_position,
        e.segment_rate  AS rate_early,  l.segment_rate  AS rate_late,
        e.segment_share AS share_early, l.segment_share AS share_late,
        e.rate_tolerance AS tolerance_early, l.rate_tolerance AS tolerance_late
    FROM early e
    JOIN late l ON l.scope = e.scope AND l.segment = e.segment
)
SELECT
    scope_position,
    scope,
    sum(share_early * rate_early)                                       AS aggregate_early,
    sum(share_late  * rate_late)                                        AS aggregate_late,
    sum(share_late  * rate_late) - sum(share_early * rate_early)        AS aggregate_change,
    sum((share_early + share_late) / 2.0 * (rate_late - rate_early))    AS within_segments,
    sum((rate_early + rate_late) / 2.0 * (share_late - share_early))    AS between_segments,
    sum(share_early * (rate_late - rate_early))                         AS within_at_early_shares,
    sum(rate_early * (share_late - share_early))                        AS between_at_early_rates,
    sum((share_late - share_early) * (rate_late - rate_early))          AS cross_term,
    min(rate_late - rate_early)                                         AS smallest_origin_gain,
    min(rate_late - rate_early - (tolerance_early + tolerance_late))    AS smallest_gain_over_band,
    count(*)                                                            AS origins
FROM paired
GROUP BY 1, 2
ORDER BY scope_position, scope;

-- And the reading that does not move for the wrong reason: the late rates at the early weights.
CREATE OR REPLACE TABLE mix_standardised AS
WITH early AS (SELECT scope, segment, segment_rate, segment_share FROM mix_reading WHERE period_position = 1),
late  AS (SELECT scope, segment, segment_rate FROM mix_reading WHERE period_position = 2)
SELECT
    a.scope_position,
    e.scope,
    sum(e.segment_share * e.segment_rate)                           AS rate_early,
    sum(e.segment_share * l.segment_rate)                           AS rate_late_standardised,
    sum(e.segment_share * l.segment_rate)
        - sum(e.segment_share * e.segment_rate)                     AS standardised_change,
    a.aggregate_rate                                                AS rate_late_as_reported,
    a.aggregate_rate - sum(e.segment_share * e.segment_rate)        AS reported_change
FROM early e
JOIN late l ON l.scope = e.scope AND l.segment = e.segment
JOIN mix_aggregate a ON a.scope = e.scope AND a.period_position = 2
GROUP BY 1, 2, a.aggregate_rate
ORDER BY a.scope_position, e.scope;

-- The same reversal in the declared parameters alone, with no sampling in it.
--
-- The composition of a period is the arrival-weighted average of the daily shares, not the share at the
-- period's midpoint. Those differ here for wave 1's own reason: arrivals grow, so the late days of a
-- period carry more subjects than the early ones and the effective mean day sits after the midpoint. A
-- midpoint reading of `campanha` in the second period says 0.40 and the arrival-weighted one says more,
-- and the gap is entirely the growth. The same correction applies to the multipliers, which also drift.
--
-- With that weighting the reversal is arithmetic rather than evidence: every origin's multiplier is
-- larger in the second period, and the weighted average of them is smaller.
CREATE OR REPLACE TABLE mix_declared AS
WITH day_arrivals AS (
    SELECT cohort_day, sum(arrivals) AS arrivals FROM arrivals GROUP BY 1
),
weighted AS (
    SELECT
        p.period,
        p.position AS period_position,
        s.segment,
        s.position AS segment_position,
        sum(a.arrivals * s.share) / sum(a.arrivals)                  AS declared_share,
        sum(a.arrivals * s.share * s.multiplier)
            / sum(a.arrivals * s.share)                              AS declared_multiplier,
        sum(a.arrivals * s.share)                                    AS declared_subjects
    FROM mix_periods_declared p
    JOIN day_arrivals a ON a.cohort_day BETWEEN p.first_day AND p.last_day
    JOIN segment_schedule s ON s.cohort_day = a.cohort_day
    GROUP BY 1, 2, 3, 4
)
SELECT
    period,
    period_position,
    segment,
    segment_position,
    declared_share,
    declared_multiplier,
    declared_subjects,
    sum(declared_share * declared_multiplier) OVER (PARTITION BY period) AS declared_aggregate,
    sum(declared_share) OVER (PARTITION BY period)                       AS shares_sum
FROM weighted
ORDER BY period_position, segment_position;
