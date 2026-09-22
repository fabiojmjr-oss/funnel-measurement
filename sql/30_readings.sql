-- The same funnel read four ways. Three of them are what dashboards show; one is a rate.
--
-- `window_rate` is the reading almost every funnel dashboard produces: count how many subjects
-- entered stage 1 during the reporting window, count how many reached stage k during the same window,
-- divide. The numerator and the denominator are **different people** - somebody who reached
-- `fechado` this month entered the funnel two months ago - so the ratio is not a conversion rate of
-- anything. It is the shape of the arrivals divided by itself at a lag.
--
-- `cumulative_rate` is the second-most-common reading: every subject ever seen, every stage ever
-- reached, divided. It is a real rate over a real population, and it is still biased, because the
-- subjects who arrived last week have not had time to finish.
--
-- `cohort_rate` is a conversion rate. Take only cohorts old enough to have had their chance, ask what
-- share of each reached stage k **within that chance**, and weight by cohort size.
--
-- `declared_rate` is the answer, which exists here and nowhere else: the product of the declared pass
-- rates. A cohort rate approaches it as the maturity window grows; nothing else has to.

CREATE OR REPLACE TABLE readings AS
WITH bounds AS (
    SELECT
        (SELECT value FROM params WHERE key = 'as_of_day')     AS as_of,
        (SELECT value FROM params WHERE key = 'window_days')    AS window_days,
        (SELECT value FROM params WHERE key = 'maturity_days')  AS maturity
),
declared AS (
    SELECT
        funnel,
        step,
        stage,
        exp(sum(ln(pass_rate)) OVER (PARTITION BY funnel ORDER BY step)) AS declared_rate
    FROM stages
),
window_counts AS (
    SELECT e.funnel, e.step, count(*) AS reached_in_window
    FROM events e, bounds b
    WHERE e.reached_day > b.as_of - b.window_days AND e.reached_day <= b.as_of
    GROUP BY 1, 2
),
window_entries AS (
    SELECT s.funnel, count(*) AS entered_in_window
    FROM subjects s, bounds b
    WHERE s.cohort_day > b.as_of - b.window_days AND s.cohort_day <= b.as_of
    GROUP BY 1
),
cumulative_counts AS (
    SELECT funnel, step, count(*) AS reached_ever
    FROM events
    WHERE observed
    GROUP BY 1, 2
),
cohort_base AS (
    SELECT s.funnel, count(*) AS eligible
    FROM subjects s, bounds b
    WHERE s.cohort_day <= b.as_of - b.maturity
    GROUP BY 1
),
cohort_counts AS (
    SELECT e.funnel, e.step, count(*) AS reached_in_time
    FROM events e, bounds b
    WHERE e.cohort_day <= b.as_of - b.maturity
      AND e.age_at_stage <= b.maturity
    GROUP BY 1, 2
)
SELECT
    f.position,
    d.funnel,
    d.step,
    d.stage,
    coalesce(wc.reached_in_window, 0)                                  AS reached_in_window,
    we.entered_in_window,
    coalesce(wc.reached_in_window, 0) / we.entered_in_window::DOUBLE    AS window_rate,
    coalesce(cc.reached_ever, 0) / (
        SELECT count(*) FROM subjects s WHERE s.funnel = d.funnel
    )::DOUBLE                                                          AS cumulative_rate,
    coalesce(oc.reached_in_time, 0) / cb.eligible::DOUBLE               AS cohort_rate,
    d.declared_rate
FROM declared d
JOIN funnels f       ON f.funnel = d.funnel
JOIN window_entries we ON we.funnel = d.funnel
JOIN cohort_base cb  ON cb.funnel = d.funnel
LEFT JOIN window_counts wc     ON wc.funnel = d.funnel AND wc.step = d.step
LEFT JOIN cumulative_counts cc ON cc.funnel = d.funnel AND cc.step = d.step
LEFT JOIN cohort_counts oc     ON oc.funnel = d.funnel AND oc.step = d.step
ORDER BY f.position, d.step;

-- The bottom line of each funnel, beside the growth rate that decides how wrong the window reading is.
CREATE OR REPLACE TABLE distortion AS
SELECT
    r.position,
    r.funnel,
    f.arrivals_growth_daily,
    r.step,
    r.stage,
    r.window_rate,
    r.cohort_rate,
    r.declared_rate,
    r.window_rate - r.cohort_rate                  AS gap,
    r.window_rate / r.cohort_rate                  AS ratio
FROM readings r
JOIN funnels f ON f.funnel = r.funnel
QUALIFY r.step = max(r.step) OVER (PARTITION BY r.funnel)
ORDER BY f.arrivals_growth_daily;
