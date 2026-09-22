-- The event log has to be a walk: no stage without the one before it, and no travel back in time.
SELECT 'a subject reached a stage without reaching the one before' AS failure,
       e.subject_id::VARCHAR AS detail, e.step::DOUBLE AS value
FROM events e
WHERE e.step > 1
  AND NOT EXISTS (
      SELECT 1 FROM events p WHERE p.subject_id = e.subject_id AND p.step = e.step - 1
  )

UNION ALL
SELECT 'a stage happened before the stage before it', e.subject_id::VARCHAR, e.step::DOUBLE
FROM events e
JOIN events p ON p.subject_id = e.subject_id AND p.step = e.step - 1
WHERE e.reached_day < p.reached_day

UNION ALL
SELECT 'a subject does not enter its funnel on its arrival day', e.subject_id::VARCHAR, e.reached_day
FROM events e WHERE e.step = 1 AND e.reached_day <> e.cohort_day

UNION ALL
SELECT 'a subject has no entry row or more than one', subject_id::VARCHAR, n::DOUBLE
FROM (SELECT subject_id, count(*) AS n FROM events WHERE step = 1 GROUP BY 1)
WHERE n <> 1

UNION ALL
SELECT 'a subject in the log is not in the population', subject_id::VARCHAR, 0
FROM events e WHERE NOT EXISTS (SELECT 1 FROM subjects s WHERE s.subject_id = e.subject_id)

UNION ALL
SELECT 'an age at a stage is negative', subject_id::VARCHAR, age_at_stage
FROM events WHERE age_at_stage < 0.0;
