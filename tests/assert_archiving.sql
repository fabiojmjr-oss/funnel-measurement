-- The review that breaks the estimator, and the exact condition under which it cannot.
--
-- The property worth having is the sharp one: a review window at or beyond the horizon being reported on
-- cannot contaminate the report, because it removes nobody before the horizon. Inside it, it can - and
-- the sign is not knowable in advance, which is the third time this repository has found an error with
-- no sign.
SELECT 'a review window at or beyond the horizon still moved the estimate' AS failure,
       funnel || ' at ' || stale_days || ' days' AS detail,
       round(ratio - 1.0, 12) AS value
FROM sweep_archiving
WHERE stale_days >= (SELECT value FROM params WHERE key = 'maturity_days')
  AND abs(ratio - 1.0) > 1e-9

UNION ALL
-- Inside the horizon it has to move it somewhere, or the mechanism is not wired up at all.
SELECT 'no review window inside the horizon moved the estimate', 'mechanism', 0
WHERE NOT EXISTS (
    SELECT 1 FROM sweep_archiving
    WHERE stale_days < (SELECT value FROM params WHERE key = 'maturity_days')
      AND abs(ratio - 1.0) > 0.01
)

UNION ALL
-- And it has to move it both ways, which is the finding.
SELECT 'the bias came out with only one sign, so it is correctable after all', 'sign', 0
WHERE NOT (
    EXISTS (SELECT 1 FROM sweep_archiving WHERE stale_days < 30 AND ratio > 1.0 + 1e-9)
    AND EXISTS (SELECT 1 FROM sweep_archiving WHERE stale_days < 30 AND ratio < 1.0 - 1e-9)
)

UNION ALL
-- The review is supposed to be better at spotting the slow class. If it is not, nothing above follows.
SELECT 'the review did not target the slow class', 'selectivity',
       round(share_archived_slow / share_population_slow, 4)
FROM (
    SELECT
        (SELECT count(*) FILTER (WHERE class = 'slow') / count(*)::DOUBLE FROM archive_decisions)
            AS share_archived_slow,
        (SELECT count(*) FILTER (WHERE class = 'slow') / count(*)::DOUBLE FROM subject_class)
            AS share_population_slow
)
WHERE share_archived_slow / share_population_slow < 1.5

UNION ALL
-- Structure: the archived curve is still a survival curve, whatever it is a curve of.
SELECT 'the archived incidence fell', funnel || ' step ' || step, round(incidence, 6)
FROM (
    SELECT funnel, step, time, incidence,
           lag(incidence) OVER (PARTITION BY funnel, step ORDER BY time) AS previous
    FROM archived_survival
)
WHERE previous IS NOT NULL AND incidence < previous - 1e-12

UNION ALL
SELECT 'the archived risk set grew', funnel || ' step ' || step, at_risk::DOUBLE
FROM (
    SELECT funnel, step, time, at_risk,
           lag(at_risk) OVER (PARTITION BY funnel, step ORDER BY time) AS previous
    FROM archived_survival
)
WHERE previous IS NOT NULL AND at_risk > previous

UNION ALL
-- Nobody can be archived before they arrived, and nobody twice.
SELECT 'a subject was archived before its own cohort day', subject_id::VARCHAR, archived_on_day
FROM archive_decisions WHERE archived_on_day < cohort_day
UNION ALL
SELECT 'a subject has more than one archiving decision', subject_id::VARCHAR, n
FROM (SELECT subject_id, count(*) AS n FROM archive_decisions GROUP BY 1) WHERE n <> 1;
