-- The queue against arithmetic done separately.
--
-- Every deviation below is recomputed here from the published columns rather than read out of the model's
-- own comparison column, for the reason recorded as defect 8: an assertion that reads a stored ratio tests
-- that the ratio was copied across, not that the two numbers agree.
--
-- The tolerance is four standard errors, and the standard error is the clustered one - the naive sd/sqrt(n)
-- is up to six times too narrow here, so a tolerance built on it would fail correct arithmetic. That is not
-- a loosening: it is the same four standard errors every other wave in this repository uses, computed from
-- a spread that accounts for the fact that a queue's waits are not independent observations.
SELECT 'a simulated mean wait is more than four clustered standard errors from its closed form' AS failure,
       discipline || ' ' || priority AS detail,
       round((simulated_wait - derived_wait) / wait_standard_error, 3) AS value
FROM queue_closed_form
WHERE abs(simulated_wait - derived_wait) > 4.0 * wait_standard_error

UNION ALL
-- First-come-first-served does not know the classes exist, so its derivation is one number and the three
-- classes have to share it exactly.
SELECT 'the first-come-first-served derivation differs between classes', 'fifo',
       round(max(derived_wait) - min(derived_wait), 12)
FROM queue_closed_form WHERE discipline = 'fifo'
HAVING max(derived_wait) - min(derived_wait) > 1e-12

UNION ALL
-- Under a priority order the derived waits have to be ordered by rank, or Cobham's formula has been fed the
-- utilisations in the wrong order - which is the one mistake in this file that would leave every number
-- looking plausible.
SELECT 'a derived wait is not ordered by the discipline rank', discipline || ' ' || priority,
       round(derived_wait, 6)
FROM (
    SELECT discipline, priority, discipline_rank, derived_wait,
           lag(derived_wait) OVER (PARTITION BY discipline ORDER BY discipline_rank) AS better_ranked
    FROM queue_closed_form WHERE discipline <> 'fifo'
)
WHERE better_ranked IS NOT NULL AND derived_wait <= better_ranked

UNION ALL
-- And the same for what the simulation actually did.
SELECT 'a simulated wait is not ordered by the discipline rank', discipline || ' ' || priority,
       round(simulated_wait, 6)
FROM (
    SELECT discipline, priority, discipline_rank, simulated_wait,
           lag(simulated_wait) OVER (PARTITION BY discipline ORDER BY discipline_rank) AS better_ranked
    FROM queue_closed_form WHERE discipline <> 'fifo'
)
WHERE better_ranked IS NOT NULL AND simulated_wait <= better_ranked

UNION ALL
-- A priority order has to be better than first-come-first-served for its top class and worse for its
-- bottom class, in the derivation as well as in the simulation. If it were better for both it would be
-- creating capacity.
SELECT 'a priority order beat first-come-first-served for its bottom class', discipline,
       round(derived_wait, 6)
FROM queue_closed_form
WHERE discipline <> 'fifo' AND discipline_rank = 3
  AND derived_wait <= (SELECT max(derived_wait) FROM queue_closed_form WHERE discipline = 'fifo')

UNION ALL
SELECT 'a priority order lost to first-come-first-served for its top class', discipline,
       round(derived_wait, 6)
FROM queue_closed_form
WHERE discipline <> 'fifo' AND discipline_rank = 1
  AND derived_wait >= (SELECT min(derived_wait) FROM queue_closed_form WHERE discipline = 'fifo')

UNION ALL
-- The conservation law as arithmetic. Three disciplines, one number, and it has to come out of Cobham's
-- formula summed over the classes as well as out of Pollaczek and Khinchine's directly.
SELECT 'the conservation law does not hold in the derivation', 'derived',
       round(spread, 15)
FROM (
    SELECT (max(derived_work_weighted_rate) - min(derived_work_weighted_rate))
           / max(derived_work_weighted_rate) AS spread
    FROM queue_conservation
)
WHERE spread > 1e-12

UNION ALL
-- The conservation law as a realisation, against the derivation.
SELECT 'the simulated work-weighted waiting is more than four standard errors from its closed form',
       discipline,
       round((simulated_work_weighted_rate - derived_work_weighted_rate)
             / (work_weighted_standard_error * (SELECT utilisation FROM queue_residual)), 3)
FROM queue_conservation
WHERE abs(simulated_work_weighted_rate - derived_work_weighted_rate)
      > 4.0 * work_weighted_standard_error * (SELECT utilisation FROM queue_residual)

UNION ALL
-- The residual work is the quantity all three formulas are built on, so it is checked against its own
-- definition rather than taken on trust.
SELECT 'the residual work does not equal the declared sum of rate times second moment over two', 'W0',
       round(residual_work - rebuilt, 12)
FROM queue_residual,
     (SELECT sum(realised_rate * realised_service_second_moment) / 2.0 AS rebuilt FROM queue_moments)
WHERE abs(residual_work - rebuilt) > 1e-12

UNION ALL
SELECT 'the utilisation does not equal the sum of the class utilisations', 'rho',
       round(utilisation - rebuilt, 12)
FROM queue_residual,
     (SELECT sum(realised_utilisation) AS rebuilt FROM queue_moments)
WHERE abs(utilisation - rebuilt) > 1e-12

UNION ALL
-- The sweep against the same formula. This is the one place the tolerance has real work to do: near
-- capacity the interval is wide because the run contains few independent busy periods, and that is the
-- point of queue_run_length rather than an excuse made here.
SELECT 'a swept point is more than four standard errors from its closed form',
       'utilisation ' || f.utilisation || ' ' || f.discipline,
       round((f.mean_wait_per_day_of_work - f.derived_wait) / s.work_weighted_standard_error, 3)
FROM queue_sweep_closed_form f
JOIN queue_sweep s ON s.utilisation = f.utilisation AND s.discipline = f.discipline
WHERE abs(f.mean_wait_per_day_of_work - f.derived_wait) > 4.0 * s.work_weighted_standard_error

UNION ALL
-- The shape of the sweep's own derivation, checked as algebra rather than as a curve. W0/(1-u) scaled by
-- u means derived_wait * (1-u)/u is the same constant at every utilisation, namely E[S^2]/(2*E[S]).
SELECT 'the swept derivation is not W0 over one minus utilisation', 'shape',
       round(spread, 12)
FROM (
    SELECT (max(constant) - min(constant)) / max(constant) AS spread
    FROM (
        SELECT derived_wait * (1.0 - utilisation) / utilisation AS constant
        FROM queue_sweep_closed_form WHERE discipline = 'fifo'
    )
)
WHERE spread > 1e-12

UNION ALL
-- And the elasticity that carries the prescription: one more percent of demand is worth 1/(1-u) percent of
-- waiting, so the same extra demand costs six times more at 0.90 than at 0.40.
SELECT 'the elasticity of waiting in demand is not one over one minus utilisation',
       'utilisation ' || utilisation, round(elasticity_of_waiting_in_demand - 1.0 / (1.0 - utilisation), 12)
FROM queue_sweep_closed_form
WHERE abs(elasticity_of_waiting_in_demand - 1.0 / (1.0 - utilisation)) > 1e-12

UNION ALL
-- The slice readings have to bracket the truth, or the comparison that maps them onto utilisations is
-- reading something else.
SELECT 'the extreme slice readings do not bracket the true mean', 'brackets', 0
WHERE NOT (
    (SELECT lowest_slice_mean FROM queue_measurability)
        < (SELECT mean_of_slice_means FROM queue_measurability)
    AND (SELECT highest_slice_mean FROM queue_measurability)
        > (SELECT mean_of_slice_means FROM queue_measurability)
)

UNION ALL
-- And the utilisation each extreme is mistakable for has to sit on the correct side of the true one.
SELECT 'a slice reading was matched to a utilisation on the wrong side of the truth', slice,
       looks_like_utilisation::DOUBLE
FROM queue_mistaken_for
WHERE (slice = 'lowest slice'
       AND looks_like_utilisation >= (SELECT looks_like_utilisation FROM queue_mistaken_for WHERE slice = 'true value'))
   OR (slice = 'highest slice'
       AND looks_like_utilisation <= (SELECT looks_like_utilisation FROM queue_mistaken_for WHERE slice = 'true value'));
