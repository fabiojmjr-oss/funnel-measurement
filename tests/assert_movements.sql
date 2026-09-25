-- Stages that are not a partition, and the control that makes the difference attributable.
--
-- The messy log is worth nothing as evidence unless it is the monotone log plus the three movements and
-- nothing else. So the first assertion here is a control world rather than a property: for every subject
-- whose skip coin came up tails, the first entry's first attempt has to be byte-identical to the event log
-- of sql/20_events.sql - same steps, same arrival days. Entry one attempt one draws salts 7 and 101, which
-- are the salts that log was built from, so any difference is a bug in this file and not a movement.
--
-- Then the three streams against their declared rates, the shape rules the walk may not break, the closed
-- form of the step-three reach, and the findings - each recomputed here from counts rather than read back
-- from the column the report published, which is the discipline defects 9 and 11 were about.
WITH honest AS (SELECT subject_id FROM movement_draws WHERE NOT skips),
control AS (
    SELECT subject_id, step, reached_day FROM messy_walk
    WHERE entry = 1 AND attempt = 1 AND subject_id IN (SELECT subject_id FROM honest)
),
monotone AS (
    SELECT subject_id, step, reached_day FROM events
    WHERE subject_id IN (SELECT subject_id FROM honest)
)
SELECT 'the messy walk of a non-skipping subject is not the monotone walk' AS failure,
       'subject ' || subject_id || ' step ' || step AS detail,
       reached_day AS value
FROM (SELECT * FROM control EXCEPT SELECT * FROM monotone)

UNION ALL
SELECT 'the monotone walk has a row the messy walk lost',
       'subject ' || subject_id || ' step ' || step, reached_day
FROM (
    SELECT subject_id, step, reached_day FROM events
    WHERE subject_id IN (SELECT subject_id FROM movement_draws WHERE NOT skips)
    EXCEPT
    SELECT subject_id, step, reached_day FROM messy_walk
    WHERE entry = 1 AND attempt = 1
      AND subject_id IN (SELECT subject_id FROM movement_draws WHERE NOT skips)
)

UNION ALL
-- The skip stream, drawn once per subject on salt 2003.
SELECT 'the observed skip share is not the declared skip rate', d.funnel,
       round(d.observed - m.skip_rate, 6)
FROM (SELECT funnel, count(*) AS n, count(*) FILTER (WHERE skips) / count(*)::DOUBLE AS observed
      FROM movement_draws GROUP BY 1) d
JOIN movements m ON m.funnel = d.funnel
WHERE abs(d.observed - m.skip_rate) > 4.0 * sqrt(m.skip_rate * (1.0 - m.skip_rate) / d.n)

UNION ALL
-- The return stream, drawn once per subject on salt 2237. This is the coin, not the event: a subject whose
-- coin is up but which finished its funnel on the first entry never comes back, which is the next assertion.
SELECT 'the observed return share is not the declared re-entry rate', d.funnel,
       round(d.observed - m.reentry_rate, 6)
FROM (SELECT funnel, count(*) AS n, count(*) FILTER (WHERE would_return) / count(*)::DOUBLE AS observed
      FROM movement_draws GROUP BY 1) d
JOIN movements m ON m.funnel = d.funnel
WHERE abs(d.observed - m.reentry_rate) > 4.0 * sqrt(m.reentry_rate * (1.0 - m.reentry_rate) / d.n)

UNION ALL
-- The fallback stream, drawn per state on salt 2111 at every state that is eligible to fall back. The
-- denominator is the eligible states themselves, because that is where the coin is actually consulted -
-- the generator assertion of wave 3 was written against streams nobody draws from, and this one is not.
SELECT 'the observed fallback share is not the declared fallback rate', f.funnel,
       round(f.k / f.n::DOUBLE - m.fallback_rate, 6)
FROM (
    SELECT e.funnel, count(*) AS n,
           count(*) FILTER (WHERE passes(e.subject_id * 16 + e.step, 2111, m2.fallback_rate)) AS k
    FROM (SELECT subject_id, funnel, step FROM messy_walk WHERE attempt = 1 AND step >= 3) e
    JOIN movements m2 ON m2.funnel = e.funnel
    GROUP BY 1
) f
JOIN movements m ON m.funnel = f.funnel
WHERE abs(f.k / f.n::DOUBLE - m.fallback_rate) > 4.0 * sqrt(m.fallback_rate * (1.0 - m.fallback_rate) / f.n)

UNION ALL
-- Shape rules. A second entry exists only for a subject whose first entry stopped short of the last stage
-- of its own funnel: a funnel nobody can re-enter after finishing is the whole point of the re-entry rate.
SELECT 'a subject re-entered a funnel it had already finished', 'subject ' || r.subject_id, r.furthest
FROM (
    SELECT f.subject_id, max(f.step)::DOUBLE AS furthest
    FROM messy_first f
    WHERE f.subject_id IN (SELECT subject_id FROM messy_walk WHERE entry = 2)
    GROUP BY 1
) r
JOIN movement_draws d ON d.subject_id = r.subject_id
JOIN (SELECT funnel, max(step) AS last_step FROM stages GROUP BY 1) l ON l.funnel = d.funnel
WHERE r.furthest >= l.last_step

UNION ALL
-- A skipper does not touch step two on the way up. It can be sent back to it, which is a fallback and
-- carries attempt two, so the rule is about attempt one only.
SELECT 'a skipping subject walked through the stage it skipped', 'subject ' || w.subject_id, w.reached_day
FROM messy_walk w
JOIN movement_draws d ON d.subject_id = w.subject_id
WHERE d.skips AND w.attempt = 1 AND w.step = 2

UNION ALL
-- Every move costs time, in both directions. A fallback that arrived before the state it came from would
-- make the walk non-terminating and the arrival days meaningless.
SELECT 'an event in the messy walk precedes its own cohort day', 'subject ' || subject_id, reached_day
FROM messy_walk WHERE reached_day < cohort_day

UNION ALL
-- A subject falls back at most once per entry, which is what switching to attempt two is for.
SELECT 'a subject fell back more than once in one entry', 'subject ' || subject_id, falls
FROM (
    SELECT subject_id, entry, count(DISTINCT step)::DOUBLE AS falls
    FROM messy_walk WHERE fell_back AND attempt = 2 AND step = (
        SELECT min(step) FROM messy_walk x WHERE x.subject_id = messy_walk.subject_id
          AND x.entry = messy_walk.entry AND x.fell_back)
    GROUP BY 1, 2
)
WHERE falls > 1

UNION ALL
-- The closed form of the step-three reach, against the first-entry eventual walk and no other population.
SELECT 'the step-three reach does not match its closed form', funnel,
       round(abs(derived_reach - simulated_reach) - tolerance, 6)
FROM movement_closed_form
WHERE abs(derived_reach - simulated_reach) > tolerance

UNION ALL
-- Recomputed rather than read back: the published reach rate has to be the counts it claims to be.
SELECT 'the published first-entry reach is not its own counts', funnel || ' step ' || step,
       round(reach_rate - reached / subjects::DOUBLE, 15)
FROM movement_first_entry_reach
WHERE abs(reach_rate - reached / subjects::DOUBLE) > 1e-12

UNION ALL
SELECT 'the published derived ratio is not the derived reach over the ceiling', funnel,
       round(derived_over_ceiling - derived_reach / declared_ceiling, 15)
FROM movement_closed_form
WHERE abs(derived_over_ceiling - derived_reach / declared_ceiling) > 1e-12

UNION ALL
-- The finding. Wave 1's cheapest diagnostic was that a stage reading above the product of the pass rates
-- proves the reading is not a rate. With a skip in the funnel the ceiling is not a ceiling: the derived
-- ratio is 1 + s*(1 - p2)/p2, above one for every funnel that has any skip at all, on a generator that is
-- obeying its declared rates exactly. The diagnostic does not detect a broken metric here; it detects a
-- stage that can be bypassed, and it cannot tell the two apart.
SELECT 'a funnel with a skip does not breach its declared ceiling', funnel,
       round(derived_over_ceiling, 6)
FROM movement_closed_form
WHERE skip_rate > 0 AND derived_over_ceiling <= 1.0

UNION ALL
-- And the breach is not only on paper: at least one funnel reads above its ceiling in the windowed cohort
-- reading, which is the reading a report actually takes.
SELECT 'no funnel breaches its ceiling in the windowed reading', 'movement_reach',
       count(*)::DOUBLE
FROM movement_reach WHERE step > 1 AND messy_over_ceiling > 1.0
HAVING count(*) = 0

UNION ALL
-- The monotone reading of the same subjects breaches it too - by sampling noise, and only by sampling
-- noise. Wave 1 stated the ceiling as an identity when it is an expectation, so a clean funnel already
-- produces breaches of about one percent on this many subjects. What the skip adds is a breach an order of
-- magnitude larger, and the pair is what makes the finding attributable: same subjects, same forward coins,
-- and the only reading that leaves the noise band is the one with movements in it.
SELECT 'the monotone reading breaches its ceiling by more than sampling noise',
       funnel || ' step ' || step,
       round(monotone_rate - declared_rate, 6)
FROM movement_reach
WHERE monotone_rate - declared_rate > 4.0 * sqrt(declared_rate * (1.0 - declared_rate) / subjects)

UNION ALL
-- Where the derivation says the breach is detectable, the eventual first-entry reading has to show it.
-- "Detectable" is twice the noise band and not once it: a funnel whose expected breach is the width of the
-- band itself lands on either side of it by luck, and an assertion that demanded otherwise would be
-- asserting that noise is small rather than that the skip is real. Retencao is exactly that funnel here.
SELECT 'a breach the derivation says is detectable is inside the noise band', funnel,
       round(simulated_reach - declared_ceiling, 6)
FROM movement_closed_form
WHERE derived_reach - declared_ceiling > 8.0 * sqrt(declared_ceiling * (1.0 - declared_ceiling) / subjects)
  AND simulated_reach - declared_ceiling <= 4.0 * sqrt(declared_ceiling * (1.0 - declared_ceiling) / subjects)

UNION ALL
-- And the finding I did not expect when I wrote the derivation. The windowed cohort reading - the reading
-- every other wave in this repository takes - does not show the breach reliably, because the maturity
-- window pulls the same figure down while the skip pushes it up. At least one funnel whose skip is large
-- enough to breach the ceiling by a wide margin reads *below* its ceiling once the window is applied. So
-- the ceiling diagnostic has both error directions at once: it fires on a healthy funnel that can be
-- bypassed, and it stays silent on one that is being bypassed. It is not a diagnostic.
SELECT 'the window never masks a breach the derivation says is detectable', 'movement_closed_form',
       count(*)::DOUBLE
FROM movement_closed_form
WHERE derived_reach - declared_ceiling > 4.0 * sqrt(declared_ceiling * (1.0 - declared_ceiling) / subjects)
  AND windowed_reach < declared_ceiling
HAVING count(*) = 0

UNION ALL
-- Counting rows instead of subjects does not bias the reading in a knowable direction. It biases it both
-- ways, on the same event log, because the entry stage is inflated by re-entries and the middle stages by
-- fallbacks, and which factor wins depends on where in the funnel the subject gave up. A correction factor
-- would need a sign, and there is not one.
SELECT 'event counting biases every stage the same way', 'movement_event_counted',
       count(*)::DOUBLE
FROM movement_event_counted WHERE step > 1
HAVING count(*) FILTER (WHERE event_over_subject > 1.0) = 0
    OR count(*) FILTER (WHERE event_over_subject < 1.0) = 0

UNION ALL
SELECT 'the published event-counted ratio is not its own two rates', funnel || ' step ' || step,
       round(event_over_subject - (event_counted_rate / subject_counted_rate), 15)
FROM movement_event_counted
WHERE abs(event_over_subject - (event_counted_rate / subject_counted_rate)) > 1e-12

UNION ALL
-- Time to reach a stage is two numbers whenever a stage can be visited twice, and the later one is later.
SELECT 'the mean last touch is earlier than the mean first touch', funnel || ' step ' || step,
       round(gap_days, 6)
FROM movement_timing WHERE gap_days < 0

UNION ALL
SELECT 'no stage is ever visited twice', 'movement_timing', count(*)::DOUBLE
FROM movement_timing WHERE share_visited_twice > 0
HAVING count(*) = 0

UNION ALL
-- The monotone staircase cannot hold these rows at all, and the count is the size of the problem.
SELECT 'the messy log is not larger than the monotone log', 'movement_dropped',
       round(events_ratio, 6)
FROM movement_dropped WHERE events_ratio <= 1.0

UNION ALL
SELECT 'the published events ratio is not its own two counts', 'movement_dropped',
       round(events_ratio - messy_events / monotone_events::DOUBLE, 15)
FROM movement_dropped
WHERE abs(events_ratio - messy_events / monotone_events::DOUBLE) > 1e-12
