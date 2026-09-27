-- The mix, and the claim that a reading can move without anything it measures moving.
--
-- The declared arithmetic comes first, because it has no sampling in it: if every origin's multiplier is
-- larger in the second period and the arrival-weighted average of them is smaller, the reversal is a
-- property of the parameters and the simulation is only being asked to agree. Then the generator, then
-- the decomposition - which is exact, so it is asserted at machine precision - and then the findings.
--
-- The pooled scope carries the findings that depend on sampling. The per-funnel scopes are published and
-- their decomposition is asserted, but the smaller funnels have a few hundred subjects per origin in the
-- first period, where a declared two-point gain is inside the noise. Claiming it anyway would be claiming
-- that noise is small.
SELECT 'a declared share vector does not sum to one' AS failure,
       cohort_day::VARCHAR AS detail,
       round(total - 1.0, 15) AS value
FROM (SELECT cohort_day, sum(share) AS total FROM segment_schedule GROUP BY 1)
WHERE abs(total - 1.0) > 1e-12

UNION ALL
SELECT 'a declared period share vector does not sum to one', period, round(shares_sum - 1.0, 15)
FROM mix_declared WHERE abs(shares_sum - 1.0) > 1e-12

UNION ALL
-- An effective pass rate is a probability. The multipliers are all at or below one for this reason, and
-- the assertion is what stops a future edit from raising one above it.
SELECT 'an effective pass rate is not a probability', segment || ' day ' || cohort_day,
       round(st.pass_rate * s.multiplier, 6)
FROM segment_schedule s
JOIN stages st ON st.step = 2
WHERE st.pass_rate * s.multiplier <= 0.0 OR st.pass_rate * s.multiplier > 1.0

UNION ALL
-- Every subject of wave 1 gets exactly one origin. A subject with none would silently shrink the
-- denominator; a subject with two would silently inflate it, and both would still produce a table.
SELECT 'a subject was not assigned exactly one origin', 'segment_draws',
       abs((SELECT count(*) FROM segment_draws) - (SELECT count(*) FROM subjects))::DOUBLE
FROM (SELECT 1)
WHERE (SELECT count(*) FROM segment_draws) <> (SELECT count(*) FROM subjects)
   OR (SELECT count(DISTINCT subject_id) FROM segment_draws) <> (SELECT count(*) FROM subjects)

UNION ALL
-- The declared reversal, in the parameters alone: every origin improves and the average of them falls.
SELECT 'a declared multiplier did not rise between the periods', d.segment,
       round(d.declared_multiplier - e.declared_multiplier, 6)
FROM mix_declared d
JOIN mix_declared e ON e.segment = d.segment AND e.period_position = 1
WHERE d.period_position = 2 AND d.declared_multiplier <= e.declared_multiplier

UNION ALL
SELECT 'the declared aggregate did not fall between the periods', 'mix_declared',
       round(max(declared_aggregate) FILTER (WHERE period_position = 2)
             - max(declared_aggregate) FILTER (WHERE period_position = 1), 6)
FROM mix_declared
HAVING max(declared_aggregate) FILTER (WHERE period_position = 2)
       >= max(declared_aggregate) FILTER (WHERE period_position = 1)

UNION ALL
-- The generator: the origin shares that came out are the arrival-weighted shares that went in.
SELECT 'an observed origin share is not the declared one', r.segment || ' ' || r.period,
       round(r.segment_share - d.declared_share, 6)
FROM mix_reading r
JOIN mix_declared d ON d.segment = r.segment AND d.period = r.period
WHERE r.scope = 'todos'
  AND abs(r.segment_share - d.declared_share)
      > 4.0 * sqrt(d.declared_share * (1.0 - d.declared_share) / r.period_subjects)

UNION ALL
-- The decomposition is exact. Not within a tolerance - exact, because the mean-weighted form collapses
-- algebraically to the difference it is decomposing. A residual here is an arithmetic error, not noise.
SELECT 'the decomposition does not account for the whole change', scope,
       round(within_segments + between_segments - aggregate_change, 15)
FROM mix_decomposition
WHERE abs(within_segments + between_segments - aggregate_change) > 1e-12

UNION ALL
-- And the familiar form is not exact, which is the reason the exact one is used. The cross term it drops
-- is a third of the pooled change here, so a reader handed the textbook split is handed a third of the
-- movement as an unexplained remainder - or, worse, as a term called "interaction".
SELECT 'the textbook decomposition leaves no residual to explain', scope,
       round(cross_term, 15)
FROM mix_decomposition
WHERE scope = 'todos' AND abs(cross_term) <= 1e-9

UNION ALL
SELECT 'the dropped cross term is negligible against the change it belongs to', scope,
       round(abs(cross_term / aggregate_change), 6)
FROM mix_decomposition
WHERE scope = 'todos' AND abs(cross_term / aggregate_change) < 0.10

UNION ALL
SELECT 'the published residual is not the two naive terms against the change', scope,
       round(cross_term - (aggregate_change - within_at_early_shares - between_at_early_rates), 15)
FROM mix_decomposition
WHERE abs(cross_term - (aggregate_change - within_at_early_shares - between_at_early_rates)) > 1e-12

UNION ALL
-- The finding. Pooled across all six funnels: the aggregate fell beyond its own band, and not one origin
-- got worse. Both halves are asserted, because either alone is unremarkable.
SELECT 'the pooled aggregate did not fall beyond its own sampling band', 'mix_aggregate',
       round(late.aggregate_rate - early.aggregate_rate, 6)
FROM mix_aggregate early
JOIN mix_aggregate late ON late.scope = early.scope AND late.period_position = 2
WHERE early.scope = 'todos' AND early.period_position = 1
  AND early.aggregate_rate - late.aggregate_rate
      <= sqrt(pow(early.rate_tolerance, 2) + pow(late.rate_tolerance, 2))

UNION ALL
SELECT 'an origin got worse while the pooled aggregate fell', e.segment,
       round(l.segment_rate - e.segment_rate, 6)
FROM mix_reading e
JOIN mix_reading l ON l.scope = e.scope AND l.segment = e.segment AND l.period_position = 2
WHERE e.scope = 'todos' AND e.period_position = 1 AND l.segment_rate < e.segment_rate

UNION ALL
-- At least two of the three gains clear the two-sample band, so the reversal is not three coin flips that
-- happened to land the same way. The third - the origin whose share is growing - has a declared gain of
-- about two points on a base near a quarter, which this many subjects cannot resolve, and the assertion
-- says two rather than three for that reason.
SELECT 'fewer than two origin gains clear the two-sample band', 'mix_reading', count(*)::DOUBLE
FROM mix_reading e
JOIN mix_reading l ON l.scope = e.scope AND l.segment = e.segment AND l.period_position = 2
WHERE e.scope = 'todos' AND e.period_position = 1
  AND l.segment_rate - e.segment_rate
      > sqrt(pow(e.rate_tolerance, 2) + pow(l.rate_tolerance, 2))
HAVING count(*) < 2

UNION ALL
-- The two halves of the decomposition point in opposite directions, and the mix is the larger of them.
-- That is the whole sentence: the origins improved, the population moved further, and the report shows
-- the sum.
SELECT 'the mix and the origins do not pull in opposite directions', scope,
       round(within_segments * between_segments, 9)
FROM mix_decomposition
WHERE scope = 'todos' AND within_segments * between_segments >= 0

UNION ALL
SELECT 'the mix effect does not dominate the within-origin effect', scope,
       round(abs(between_segments / within_segments), 4)
FROM mix_decomposition
WHERE scope = 'todos' AND abs(between_segments) <= abs(within_segments)

UNION ALL
-- Holding the weights at the first period's composition flips the sign of the reported change. Same
-- subjects, same conversions, same definition of converted - one different set of weights.
SELECT 'standardising the mix does not flip the sign of the reported change', scope,
       round(standardised_change, 6)
FROM mix_standardised
WHERE scope = 'todos' AND NOT (reported_change < 0.0 AND standardised_change > 0.0)

UNION ALL
SELECT 'the published reported change is not its own two rates', scope,
       round(reported_change - (rate_late_as_reported - rate_early), 15)
FROM mix_standardised
WHERE abs(reported_change - (rate_late_as_reported - rate_early)) > 1e-12

UNION ALL
-- And this is not wave 1's censoring wearing a different hat. Both periods end at or before the last day
-- a cohort can be fully mature, so the prescription of wave 1 is already applied to every figure above
-- and the reversal survives it. If a period ever reaches past that day, the two mechanisms are mixed and
-- nothing here is attributable.
SELECT 'a period contains cohorts that cannot be mature', period,
       (last_day - ((SELECT value FROM params WHERE key = 'as_of_day')
                    - (SELECT value FROM params WHERE key = 'maturity_days')))::DOUBLE
FROM mix_periods_declared
WHERE last_day > (SELECT value FROM params WHERE key = 'as_of_day')
                 - (SELECT value FROM params WHERE key = 'maturity_days')

UNION ALL
-- Recomputed rather than read back, which is the discipline defects 9 and 11 were about.
SELECT 'the published segment rate is not its own counts', scope || ' ' || segment || ' ' || period,
       round(segment_rate - converted / subjects::DOUBLE, 15)
FROM mix_reading
WHERE abs(segment_rate - converted / subjects::DOUBLE) > 1e-12

UNION ALL
SELECT 'the aggregate rate and the weighted rate disagree', scope || ' ' || period,
       round(aggregate_rate - weighted_rate, 15)
FROM mix_aggregate
WHERE abs(aggregate_rate - weighted_rate) > 1e-12

UNION ALL
-- A published figure has to be a number, which is the discipline defect 19 was about.
SELECT 'a published mix figure is not a finite number', t.name || ' ' || t.detail, t.value
FROM (
    SELECT 'mix_reading' AS name, scope || ' ' || segment || ' ' || period AS detail, segment_rate AS value
        FROM mix_reading
    UNION ALL SELECT 'mix_reading', scope || ' ' || segment || ' ' || period, segment_share FROM mix_reading
    UNION ALL SELECT 'mix_aggregate', scope || ' ' || period, aggregate_rate FROM mix_aggregate
    UNION ALL SELECT 'mix_decomposition', scope, aggregate_change FROM mix_decomposition
    UNION ALL SELECT 'mix_decomposition', scope, within_segments FROM mix_decomposition
    UNION ALL SELECT 'mix_decomposition', scope, between_segments FROM mix_decomposition
    UNION ALL SELECT 'mix_decomposition', scope, cross_term FROM mix_decomposition
    UNION ALL SELECT 'mix_standardised', scope, standardised_change FROM mix_standardised
    UNION ALL SELECT 'mix_declared', period || ' ' || segment, declared_multiplier FROM mix_declared
) t
WHERE t.value IS NULL OR isnan(t.value) OR isinf(t.value)
