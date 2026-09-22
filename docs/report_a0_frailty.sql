-- What extra spread costs the measured speed, at a true mean that has not moved.
SELECT
    b.funnel,
    round(b.observed_mean, 4)                    AS one_exponential,
    round(f.observed_mean, 4)                    AS two_classes,
    round(f.observed_mean / b.observed_mean, 4)  AS ratio
FROM (SELECT funnel, avg(age_at_stage) AS observed_mean FROM events
      WHERE step = 2 AND observed GROUP BY 1) b
JOIN (SELECT funnel, avg(age_at_stage) AS observed_mean FROM frail_events
      WHERE step = 2 AND observed GROUP BY 1) f USING (funnel)
ORDER BY ratio;
