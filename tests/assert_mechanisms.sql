-- The two mechanisms, isolated, as properties rather than as figures.
--
-- One: with the delay held fixed, the window reading falls as arrivals grow, crosses the flat-arrival
-- value exactly at zero growth, and never stops falling.
--
-- Two: with arrivals held flat, the window reading **is** the declared eventual rate - for any delay -
-- while the cohort reading falls away from it as the delay grows. The window reading is a steady-state
-- estimator of the wrong quantity, which is a sharper statement than calling it biased.
SELECT 'the window reading is not monotone falling in arrival growth' AS failure,
       growth::VARCHAR AS detail,
       round(window_rate, 6) AS value
FROM (
    SELECT growth, window_rate,
           lag(window_rate) OVER (ORDER BY growth) AS previous
    FROM sweep_growth
)
WHERE previous IS NOT NULL AND window_rate >= previous

UNION ALL
SELECT 'the cohort reading moved with the arrival growth', growth::VARCHAR, round(cohort_rate, 9)
FROM sweep_growth
WHERE abs(cohort_rate - (SELECT max(cohort_rate) FROM sweep_growth)) > 1e-12

UNION ALL
SELECT 'at zero growth the window reading is not the declared eventual rate', '0', round(window_rate - p, 9)
FROM sweep_growth WHERE growth = 0.0 AND abs(window_rate - p) > 1e-9

UNION ALL
-- The same identity across every delay, where the only departure is the 180 days of history the
-- derivation assumes to be infinite. Worst case 0.0019 at a 30-day mean delay, published as such.
SELECT 'at zero growth the window reading left the declared rate by more than the truncation',
       m::VARCHAR, round(window_rate - p, 9)
FROM sweep_lag WHERE m <= 30 AND abs(window_rate - p) > 0.002

UNION ALL
SELECT 'the cohort reading does not fall as the delay grows', m::VARCHAR, round(cohort_rate, 6)
FROM (SELECT m, cohort_rate, lag(cohort_rate) OVER (ORDER BY m) AS previous FROM sweep_lag)
WHERE previous IS NOT NULL AND cohort_rate >= previous

UNION ALL
-- A cohort rate is a truncation of the eventual rate, so **in expectation** it cannot exceed it. The
-- first version of this assertion left out those two words and failed on six stages whose delays are
-- so short that the truncation removes nothing measurable - the sample then straddles the ceiling by
-- less than a standard error. The tolerance is four of them, computed from the cohort denominator,
-- because a population identity asserted on a sample is a different claim.
SELECT 'a cohort reading exceeded the eventual rate by more than sampling noise allows',
       r.funnel || ' step ' || r.step,
       round((r.cohort_rate - r.declared_rate) / sqrt(r.declared_rate * (1 - r.declared_rate) / e.eligible), 3)
FROM readings r
JOIN (
    SELECT s.funnel, count(*) AS eligible
    FROM subjects s
    WHERE s.cohort_day <= (SELECT value FROM params WHERE key = 'as_of_day')
                        - (SELECT value FROM params WHERE key = 'maturity_days')
    GROUP BY 1
) e ON e.funnel = r.funnel
WHERE r.step > 1
  AND (r.cohort_rate - r.declared_rate) / sqrt(r.declared_rate * (1 - r.declared_rate) / e.eligible) > 4.0;
