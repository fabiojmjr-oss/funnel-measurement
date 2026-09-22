-- The queue, and the one identity the whole wave rests on.
--
-- The claim is not that priority helps a little less than people think. It is that the work-weighted total
-- waiting is the *same number* under every order the queue can be served in - not approximately, not in
-- expectation, but in this realisation and every other. An identity that exact deserves an assertion that
-- tight, so it is asserted at a relative 1e-12 and not at a tolerance.
--
-- The simulation is verified the same way: the instants at which the server goes idle cannot depend on the
-- order, so every busy period has to end at the same moment under every discipline. That is what licensed
-- decomposing one 60,000-step recursion into thousands of independent ones, so it is checked rather than
-- assumed.
SELECT 'a busy period ended at a different instant under a different discipline' AS failure,
       'period ' || busy_period AS detail,
       round(spread, 12) AS value
FROM (
    SELECT busy_period, max(ends_at) - min(ends_at) AS spread
    FROM (SELECT discipline, busy_period, max(depart) AS ends_at FROM queue_waits GROUP BY 1, 2)
    GROUP BY busy_period
)
WHERE spread > 1e-6

UNION ALL
-- The server is never idle inside a busy period, under any discipline, so the period's length is exactly
-- the work in it. This is the same statement as the one above and it fails differently: the one above
-- catches a discipline that served the wrong demands, this one catches a server that stopped.
SELECT 'a busy period is not as long as the work in it', 'period ' || busy_period,
       round(span - work, 12)
FROM (
    SELECT discipline, busy_period, max(depart) - min(arrival) AS span, sum(service) AS work
    FROM queue_waits GROUP BY 1, 2
)
WHERE abs(span - work) > 1e-6

UNION ALL
-- The invariant, at machine precision.
SELECT 'the work-weighted waiting is not the same under every discipline', 'total',
       round(spread, 15)
FROM (
    SELECT (max(work_weighted_wait) - min(work_weighted_wait)) / max(work_weighted_wait) AS spread
    FROM queue_totals
)
WHERE spread > 1e-12

UNION ALL
SELECT 'the work-weighted mean wait is not the same under every discipline', 'mean',
       round(spread, 15)
FROM (
    SELECT (max(mean_wait_per_day_of_work) - min(mean_wait_per_day_of_work))
           / max(mean_wait_per_day_of_work) AS spread
    FROM queue_totals
)
WHERE spread > 1e-12

UNION ALL
-- And the same at every swept utilisation, or the invariance is a coincidence of one operating point.
SELECT 'the work-weighted waiting is not invariant at this utilisation', 'utilisation ' || utilisation,
       round(spread, 15)
FROM (
    SELECT utilisation,
           (max(work_weighted_wait) - min(work_weighted_wait)) / max(work_weighted_wait) AS spread
    FROM queue_sweep
    WHERE utilisation IN (SELECT utilisation FROM queue_sweep GROUP BY 1 HAVING count(*) = 3)
    GROUP BY 1
)
WHERE spread > 1e-12

UNION ALL
-- The other half of the finding. If the per-demand mean were invariant too there would be nothing to say,
-- so the fact that it is not is asserted rather than admired.
SELECT 'the reported per-demand mean wait did not move with the discipline', 'spread',
       round(spread, 6)
FROM (
    SELECT (max(mean_wait_per_demand) - min(mean_wait_per_demand))
           / min(mean_wait_per_demand) AS spread
    FROM queue_totals
)
WHERE spread < 0.10

UNION ALL
-- The two orders have to move it in opposite directions, which is what makes the metric misleading rather
-- than merely noisy.
SELECT 'the two priority orders did not straddle first-come-first-served', 'direction', 0
WHERE NOT (
    (SELECT mean_wait_per_demand FROM queue_totals WHERE discipline = 'priority')
        > (SELECT mean_wait_per_demand FROM queue_totals WHERE discipline = 'fifo')
    AND (SELECT mean_wait_per_demand FROM queue_totals WHERE discipline = 'reversed')
        < (SELECT mean_wait_per_demand FROM queue_totals WHERE discipline = 'fifo')
)

UNION ALL
-- Structure of the simulation. A demand chosen before it arrived would mean the busy-period decomposition
-- was wrong about the server never having to idle, and the only trace it would leave is a negative wait.
SELECT 'a demand was served before it arrived', job_id::VARCHAR, round(wait, 12)
FROM queue_waits WHERE wait < -1e-9

UNION ALL
SELECT 'a demand was not served exactly once under every discipline', job_id::VARCHAR, n
FROM (SELECT job_id, count(*) AS n FROM queue_waits GROUP BY 1) WHERE n <> 3

UNION ALL
SELECT 'a departure does not equal the arrival plus the wait plus the handling',
       job_id::VARCHAR, round(depart - (arrival + wait + service), 12)
FROM queue_waits WHERE abs(depart - (arrival + wait + service)) > 1e-6

UNION ALL
SELECT 'a demand changed class between disciplines', job_id::VARCHAR, 0
FROM (SELECT job_id, count(DISTINCT priority) AS n FROM queue_waits GROUP BY 1) WHERE n <> 1

UNION ALL
-- The draw, against what was declared. Separated from everything above on purpose: this is a statement
-- about the generator and not about the queue, and the closed-form file needs it to be true before its own
-- comparison means anything.
SELECT 'a realised class share is more than four standard errors from the declared one',
       priority, round(realised_share - declared_share, 6)
FROM queue_moments WHERE abs(realised_share - declared_share) > share_tolerance

UNION ALL
SELECT 'a realised mean handling time is more than four standard errors from the declared one',
       priority, round(realised_service_mean - declared_service_mean, 6)
FROM queue_moments WHERE abs(realised_service_mean - declared_service_mean) > service_mean_tolerance

UNION ALL
-- An exponential has a second moment of twice the square of its mean, and that is the only property of
-- the service distribution the closed forms use.
SELECT 'a realised second moment of handling time is not twice the square of its mean',
       priority, round(realised_service_second_moment / (2.0 * realised_service_mean * realised_service_mean), 4)
FROM queue_moments
WHERE abs(realised_service_second_moment / (2.0 * realised_service_mean * realised_service_mean) - 1.0) > 0.08

UNION ALL
-- The sweep changes one parameter, and the point of scaling the arrival instants the way it does is that
-- each point's realised utilisation lands on the declared grid value exactly. If it does not, every figure
-- read off the sweep is being attributed to the wrong utilisation.
SELECT 'a swept point did not land on its declared utilisation', 'utilisation ' || utilisation,
       round(realised - utilisation, 12)
FROM (
    SELECT utilisation, sum(service) / max(arrival) AS realised
    FROM queue_sweep_input GROUP BY 1
)
WHERE abs(realised - utilisation) > 1e-9

UNION ALL
-- Waiting has to rise with utilisation, at every point, or the sweep is not measuring what it claims to.
SELECT 'waiting did not rise with utilisation', 'utilisation ' || utilisation,
       round(mean_wait_per_day_of_work, 6)
FROM (
    SELECT utilisation, mean_wait_per_day_of_work,
           lag(mean_wait_per_day_of_work) OVER (ORDER BY utilisation) AS previous
    FROM queue_sweep WHERE discipline = 'fifo'
)
WHERE previous IS NOT NULL AND mean_wait_per_day_of_work <= previous

UNION ALL
-- The interval. The cluster-robust standard error has to be wider than sd/sqrt(n) for every class of every
-- discipline, because waits inside a busy period are positively correlated and the naive form assumes they
-- are not. A case where it came out narrower would mean the clustering was wrong.
SELECT 'the clustered standard error came out narrower than the naive one',
       discipline || ' ' || priority, round(standard_error_inflation, 4)
FROM queue_readings WHERE standard_error_inflation <= 1.0

UNION ALL
-- And it has to be *materially* wider somewhere, or the published finding about it is noise.
SELECT 'the naive standard error was not materially understated anywhere', 'inflation',
       round(max(standard_error_inflation), 4)
FROM queue_readings HAVING max(standard_error_inflation) < 3.0

UNION ALL
-- Service levels. Waiting cannot help, so attainment can never exceed what the same demands would have
-- achieved with no queue at all. This is an identity per demand, not a tendency, so it is exact.
SELECT 'a service level beat the level the handling time alone allows',
       discipline || ' ' || priority, round(sla_met - sla_met_without_waiting, 12)
FROM queue_readings WHERE sla_met > sla_met_without_waiting + 1e-12

UNION ALL
-- The priority order has to be the best available deal for the top class and the worst for the bottom one,
-- or the disciplines are mislabelled.
SELECT 'the priority order was not the best available for the critical class', 'p1',
       round(mean_wait, 6)
FROM queue_readings
WHERE priority = 'p1'
  AND mean_wait < (SELECT mean_wait FROM queue_readings WHERE discipline = 'priority' AND priority = 'p1')

UNION ALL
-- Run length. At the declared utilisation the estimate has to have settled, or nothing else in this file is
-- measuring the queue rather than the length of the run.
--
-- The ratio is recomputed here from the two published columns rather than read out of the model's own
-- `ratio_to_derivation`. An assertion that trusts a derived column is testing that the column was copied,
-- not that the numbers agree - and a negative test of this file caught exactly that: a corrupted mean with
-- its stored ratio left alone passed every assertion that read the ratio.
SELECT 'the estimate had not settled at the declared utilisation by the full run length',
       'run ' || run_length, round(mean_wait_per_day_of_work / derived_wait, 4)
FROM queue_run_length
WHERE utilisation = 0.78 AND run_length >= 20000
  AND abs(mean_wait_per_day_of_work / derived_wait - 1.0) > 0.05

UNION ALL
-- And near capacity it has to not have settled, and to read low, which is the finding.
SELECT 'a short run near capacity did not read low', 'utilisation ' || utilisation,
       round(mean_wait_per_day_of_work / derived_wait, 4)
FROM queue_run_length
WHERE utilisation >= 0.95 AND run_length = 5000 AND mean_wait_per_day_of_work / derived_wait > 0.60

UNION ALL
SELECT 'the estimate near capacity did not climb with the run length', 'utilisation ' || utilisation,
       round(mean_wait_per_day_of_work, 4)
FROM (
    SELECT utilisation, run_length, mean_wait_per_day_of_work,
           lag(mean_wait_per_day_of_work) OVER (PARTITION BY utilisation ORDER BY run_length) AS previous
    FROM queue_run_length
)
WHERE previous IS NOT NULL AND mean_wait_per_day_of_work <= previous

UNION ALL
-- Every one of the nine readings is below the derivation. Unlike every other error in this repository this
-- one has a sign, and the assertion is that it does.
SELECT 'a run-length reading came out above the derivation, so the bias has no sign after all',
       'utilisation ' || utilisation || ' run ' || run_length,
       round(mean_wait_per_day_of_work / derived_wait, 4)
FROM queue_run_length WHERE mean_wait_per_day_of_work > derived_wait

UNION ALL
-- Measurability. The spread of the slice means is the true standard deviation of one slice's mean, because
-- nothing differs between the slices. If the naive interval were not much narrower than that, the published
-- claim about a quarterly review would be wrong.
SELECT 'the naive interval on a 180-day slice was not materially too narrow', 'understatement',
       round(interval_understated_by, 4)
FROM queue_measurability WHERE interval_understated_by < 4.0

UNION ALL
SELECT 'the slices of an unchanging queue did not read materially differently', 'widest pair',
       round(widest_pair_of_readings, 4)
FROM queue_measurability WHERE widest_pair_of_readings < 5.0

UNION ALL
-- The two extreme slices have to be attributable to different utilisations, which is what makes the
-- reading actionable and wrong rather than merely imprecise.
SELECT 'the extreme slices of one queue were not mistakable for different utilisations', 'range', 0
FROM (
    SELECT count(DISTINCT looks_like_utilisation) AS n FROM queue_mistaken_for
) WHERE n < 3;
