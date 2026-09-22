-- One funnel, stage by stage, in all four readings. The sales funnel because it is the one every
-- company draws on a slide.
SELECT
    step,
    stage,
    round(window_rate, 4)      AS dashboard,
    round(cumulative_rate, 4)  AS all_time,
    round(cohort_rate, 4)      AS cohort_30d,
    round(declared_rate, 4)    AS eventual_ceiling
FROM readings
WHERE funnel = 'venda'
ORDER BY step;
