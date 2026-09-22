-- One row per subject, and the day it entered its funnel.
--
-- The arrival count of a day is the funnel's base times its declared daily growth compounded, which
-- is the whole mechanism behind wave 1's finding: a funnel whose arrivals grow has more young
-- cohorts in any window than old ones, and a young cohort has not had time to convert yet.

CREATE OR REPLACE TABLE arrivals AS
WITH horizon AS (SELECT value AS as_of FROM params WHERE key = 'as_of_day')
SELECT
    f.funnel,
    d.cohort_day,
    greatest(
        1,
        cast(round(f.arrivals_base * pow(1.0 + f.arrivals_growth_daily, d.cohort_day)) AS INTEGER)
    ) AS arrivals
FROM funnels f
CROSS JOIN horizon h
CROSS JOIN range(0, h.as_of + 1) d(cohort_day);

CREATE OR REPLACE TABLE subjects AS
SELECT
    row_number() OVER (ORDER BY a.funnel, a.cohort_day, s.n) AS subject_id,
    a.funnel,
    a.cohort_day
FROM arrivals a
CROSS JOIN range(1, a.arrivals + 1) s(n);
