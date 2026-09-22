-- The declared parameters have to be a funnel before anything reads them as one.
SELECT 'stage list is not contiguous from 1' AS failure, funnel, step
FROM (SELECT funnel, step, row_number() OVER (PARTITION BY funnel ORDER BY step) AS expected FROM stages)
WHERE step <> expected

UNION ALL
SELECT 'entry step is not certain and immediate', funnel, step
FROM stages WHERE step = 1 AND (pass_rate <> 1.0 OR lag_mean_days <> 0.0)

UNION ALL
SELECT 'a pass rate is not a probability', funnel, step
FROM stages WHERE pass_rate <= 0.0 OR pass_rate > 1.0

UNION ALL
SELECT 'a mean delay is negative', funnel, step
FROM stages WHERE lag_mean_days < 0.0

UNION ALL
SELECT 'a funnel has no stages declared', funnel, 0
FROM funnels f WHERE NOT EXISTS (SELECT 1 FROM stages s WHERE s.funnel = f.funnel)

UNION ALL
SELECT 'a stage belongs to no declared funnel', funnel, step
FROM stages s WHERE NOT EXISTS (SELECT 1 FROM funnels f WHERE f.funnel = s.funnel)

UNION ALL
SELECT 'the six funnels of the README are not the six here', 'count', count(*)::INTEGER
FROM funnels HAVING count(*) <> 6

UNION ALL
SELECT 'the maturity window is not the reporting window', 'days', 0
WHERE (SELECT value FROM params WHERE key = 'maturity_days')
   <> (SELECT value FROM params WHERE key = 'window_days');
