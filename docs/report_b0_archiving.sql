-- What the pipeline review costs the estimate, as its window tightens against the horizon reported on.
SELECT
    stale_days                          AS review_window_days,
    funnel,
    round(slow_lag, 1)                  AS slow_class_delay,
    round(honest_incidence, 4)          AS truth,
    round(archived_incidence, 4)        AS estimate,
    round(ratio, 4)                     AS estimate_over_truth
FROM sweep_archiving
WHERE funnel IN ('retencao', 'venda', 'resgate')
ORDER BY funnel, stale_days;
