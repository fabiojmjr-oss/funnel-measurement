-- The change somebody shipped, and every claim wave 10 makes about it.
--
-- Two exact controls come first, because everything else is a difference between two logs and a difference
-- is worth nothing until both sides are pinned. Entry into the changed world draws salts 7 and 101, the
-- salts sql/20_events.sql was built from, so a subject that arrived before the change must walk it exactly
-- as wave 1 recorded, and the counterfactual of a subject that arrived after it must do the same. Both are
-- checked row for row and day for day rather than in aggregate.
--
-- Then the structural consequences of the coupling, which are exact rather than statistical: a multiplier at
-- or above one can only ever add a conversion, a change that moves a delay cannot move a single conversion,
-- and a change that moves nothing cannot move a single date. Then the closed form. Then the findings.
SELECT 'a subject that arrived before the change did not walk wave 1''s log' AS failure,
       'subject ' || subject_id || ' step ' || step AS detail,
       reached_day AS value
FROM (
    SELECT subject_id, step, reached_day FROM intervention_events WHERE world = 'actual' AND NOT treated
    EXCEPT
    SELECT e.subject_id, e.step, e.reached_day FROM events e
    JOIN intervention_subjects b ON b.subject_id = e.subject_id AND b.world = 'actual' AND NOT b.treated
)

UNION ALL
SELECT 'wave 1''s log has a row the untreated world lost',
       'subject ' || subject_id || ' step ' || step, reached_day
FROM (
    SELECT e.subject_id, e.step, e.reached_day FROM events e
    JOIN intervention_subjects b ON b.subject_id = e.subject_id AND b.world = 'actual' AND NOT b.treated
    EXCEPT
    SELECT subject_id, step, reached_day FROM intervention_events WHERE world = 'actual' AND NOT treated
)

UNION ALL
-- The counterfactual is the world where the change was not shipped, so on the treated subjects it has to be
-- wave 1's log exactly. If it is not, the "effect" this wave measures is partly the construction.
SELECT 'the counterfactual is not wave 1''s log', 'subject ' || subject_id || ' step ' || step, reached_day
FROM (
    (SELECT subject_id, step, reached_day FROM intervention_events WHERE world = 'counterfactual'
     EXCEPT
     SELECT e.subject_id, e.step, e.reached_day FROM events e
     JOIN intervention_subjects b ON b.subject_id = e.subject_id AND b.world = 'counterfactual')
    UNION ALL
    (SELECT e.subject_id, e.step, e.reached_day FROM events e
     JOIN intervention_subjects b ON b.subject_id = e.subject_id AND b.world = 'counterfactual'
     EXCEPT
     SELECT subject_id, step, reached_day FROM intervention_events WHERE world = 'counterfactual')
)

UNION ALL
-- A multiplier that pushes a declared probability above one is not an intervention, it is a typo.
SELECT 'an effective pass rate is not a probability', funnel || ' step ' || step || ' ' || era, pass_rate
FROM stages_effective WHERE pass_rate <= 0.0 OR pass_rate > 1.0

UNION ALL
-- Common random numbers, and what they buy. The changed world reads the same uniform draw against a larger
-- threshold, so a subject that cleared the stage before still clears it. Nobody is made worse off by a
-- multiplier at or above one, and that is a property of the construction rather than of the sample - it must
-- hold exactly, at every funnel, or the coupling is broken and the paired tolerance below is not valid.
SELECT 'a subject lost a conversion to a change that only raised a rate', funnel, subjects_lost::DOUBLE
FROM lift_eventual WHERE rate_multiplier >= 1.0 AND subjects_lost > 0

UNION ALL
-- A change that moves only a delay moves no conversion at all, ever - not approximately, exactly. The
-- eventual reach of a stage does not depend on how long the walk took to get there, so the two worlds have
-- the identical set of subject-stages and differ only in the dates on them.
SELECT 'a change that moved only a delay moved a conversion', i.funnel, d.rows::DOUBLE
FROM interventions i
JOIN (
    SELECT funnel, count(*) AS rows FROM (
        (SELECT funnel, subject_id, step FROM intervention_events WHERE world = 'actual' AND treated
         EXCEPT
         SELECT funnel, subject_id, step FROM intervention_events WHERE world = 'counterfactual')
        UNION ALL
        (SELECT funnel, subject_id, step FROM intervention_events WHERE world = 'counterfactual'
         EXCEPT
         SELECT funnel, subject_id, step FROM intervention_events WHERE world = 'actual' AND treated)
    ) GROUP BY 1
) d ON d.funnel = i.funnel
WHERE i.rate_multiplier = 1.0

UNION ALL
-- And it does have to move the dates, or the intervention was never applied and every zero below is a zero
-- for the wrong reason. This is the assertion that would have caught a silent join failure.
SELECT 'a change that moves a delay moved no date', i.funnel, coalesce(m.moved, 0)::DOUBLE
FROM interventions i
LEFT JOIN (
    SELECT a.funnel, count(*) AS moved
    FROM intervention_events a
    JOIN intervention_events c
      ON c.subject_id = a.subject_id AND c.step = a.step AND c.world = 'counterfactual'
    WHERE a.world = 'actual' AND a.treated AND a.reached_day <> c.reached_day
    GROUP BY 1
) m ON m.funnel = i.funnel
WHERE i.lag_multiplier <> 1.0 AND coalesce(m.moved, 0) = 0

UNION ALL
-- The placebo changes nothing whatsoever, dates included. It is here so that a measured lift of zero on this
-- account has a known meaning.
SELECT 'the placebo changed something', i.funnel, coalesce(m.moved, 0)::DOUBLE
FROM interventions i
LEFT JOIN (
    SELECT a.funnel, count(*) AS moved
    FROM intervention_events a
    JOIN intervention_events c
      ON c.subject_id = a.subject_id AND c.step = a.step AND c.world = 'counterfactual'
    WHERE a.world = 'actual' AND a.treated AND a.reached_day <> c.reached_day
    GROUP BY 1
) m ON m.funnel = i.funnel
WHERE i.kind = 'placebo' AND coalesce(m.moved, 0) > 0

UNION ALL
-- The closed form. A multiplier on one stage's pass rate multiplies the product of the pass rates by exactly
-- that, so the eventual reach ratio is the multiplier and the causal lift is the multiplier minus one. The
-- tolerance is four standard errors of a ratio of two correlated means by the delta method, covariance term
-- included, because the numerator and the denominator share their coins.
SELECT 'the eventual causal lift does not match its closed form', funnel,
       round(abs(causal_lift - declared_lift) - tolerance, 6)
FROM lift_eventual
WHERE abs(causal_lift - declared_lift) > tolerance

UNION ALL
-- And where the coupling is perfect the closed form is exact, so nothing is allowed to hide behind the band.
SELECT 'a change that raised no rate has a non-zero eventual lift', funnel, round(causal_lift, 15)
FROM lift_eventual WHERE rate_multiplier = 1.0 AND abs(causal_lift) > 1e-12

UNION ALL
-- Recomputed rather than read back, which is the discipline defects 9 and 11 were about.
SELECT 'the published causal lift is not its own two rates', funnel,
       round(causal_lift - (actual_rate / counterfactual_rate - 1.0), 15)
FROM lift_eventual
WHERE abs(causal_lift - (actual_rate / counterfactual_rate - 1.0)) > 1e-12

UNION ALL
SELECT 'the published measured lift is not its own two rates', funnel || ' at ' || maturity,
       round(measured_lift - (actual_rate / counterfactual_rate - 1.0), 15)
FROM lift_by_maturity
WHERE abs(measured_lift - (actual_rate / counterfactual_rate - 1.0)) > 1e-12

UNION ALL
-- Finding 1. A change that converted nobody is credited with a lift at the declared reporting maturity, and
-- not a marginal one. This is the wave: the reading is not measuring conversion, it is measuring arrival
-- dates, and a change that pulls the same conversions forward moves it.
SELECT 'no worthless change is credited with a lift at the declared maturity', 'lift_by_maturity',
       count(*)::DOUBLE
FROM lift_by_maturity
WHERE maturity = (SELECT value FROM params WHERE key = 'maturity_days')
  AND declared_lift = 0.0 AND measured_lift > 0.10
HAVING count(*) = 0

UNION ALL
-- Finding 2. The measured lift of a change that raised no rate decays as the horizon lengthens, and reaches
-- the truth only when the horizon outlasts the funnel. That decay is the only signature separating it from a
-- real lift, which is why the shape of the curve and not a single reading is the diagnostic.
SELECT 'the measured lift of a delay change does not decay with the horizon',
       m.funnel || ' ' || m.maturity || ' after ' || p.maturity,
       round(m.measured_lift - p.measured_lift, 6)
FROM lift_by_maturity m
JOIN lift_by_maturity p ON p.funnel = m.funnel AND p.maturity < m.maturity
JOIN interventions i ON i.funnel = m.funnel
WHERE i.rate_multiplier = 1.0 AND i.lag_multiplier <> 1.0
  AND m.measured_lift > p.measured_lift

UNION ALL
-- Finding 3. At some horizon in the declared set, a change that raised a real rate is outranked by one that
-- raised none. The ranking a review receives is decided by the horizon, not by the effect.
SELECT 'no real effect is ever outranked by a worthless one', 'lift_ranking', count(*)::DOUBLE
FROM lift_ranking
WHERE declared_lift > 0.0 AND measured_lift < best_worthless_lift
HAVING count(*) = 0

UNION ALL
-- Finding 4. The before-and-after window comparison - the one with no counterfactual in it at all - buries a
-- real rate lift by more than a factor of five, because the conversions falling inside the post-change
-- window mostly belong to subjects who arrived before it.
SELECT 'the window reading does not bury a real rate lift', 'lift_windows', count(*)::DOUBLE
FROM lift_windows WHERE declared_lift > 0.0 AND declared_lift / window_lift > 5.0
HAVING count(*) = 0

UNION ALL
-- Finding 5. And on that same comparison the largest apparent win belongs to a change that converted nobody,
-- ahead of every change that did. Both halves are asserted, because either alone would be a curiosity.
SELECT 'the best window lift belongs to a change that did something', 'lift_windows',
       round(max(window_lift) FILTER (WHERE declared_lift = 0.0)
             - max(window_lift) FILTER (WHERE declared_lift > 0.0), 6)
FROM lift_windows
HAVING max(window_lift) FILTER (WHERE declared_lift = 0.0)
       <= max(window_lift) FILTER (WHERE declared_lift > 0.0)

UNION ALL
SELECT 'the published window lift is not its own two rates', funnel,
       round(window_lift - (window_rate_after / window_rate_before - 1.0), 15)
FROM lift_windows
WHERE abs(window_lift - (window_rate_after / window_rate_before - 1.0)) > 1e-12
UNION ALL
-- A published figure has to be a number.
--
-- A funnel whose baseline converted nobody inside a five-day horizon produces a lift of zero over zero, and
-- DuckDB orders NaN as larger than every real value: `nan > 0.10` is true, and `rank() OVER (ORDER BY x DESC)`
-- puts it first. So an undefined ratio was ranked the best intervention of the six, and the comparison
-- assertions agreed with it. The rows where the baseline is empty are now excluded where they are built, and
-- this assertion is what stops that filter from being removed quietly. Defect 19.
SELECT 'a published lift is not a finite number', t.name || ' ' || t.detail, t.value
FROM (
    SELECT 'lift_eventual' AS name, funnel AS detail, causal_lift AS value FROM lift_eventual
    UNION ALL SELECT 'lift_eventual', funnel, tolerance FROM lift_eventual
    UNION ALL SELECT 'lift_by_maturity', funnel || ' ' || maturity, measured_lift FROM lift_by_maturity
    UNION ALL SELECT 'lift_by_maturity', funnel || ' ' || maturity, tolerance FROM lift_by_maturity
    UNION ALL SELECT 'lift_ranking', funnel || ' ' || maturity, measured_lift FROM lift_ranking
    UNION ALL SELECT 'lift_windows', funnel, window_lift FROM lift_windows
) t
WHERE t.value IS NULL OR isnan(t.value) OR isinf(t.value)
