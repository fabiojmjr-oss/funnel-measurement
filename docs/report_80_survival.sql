-- What the product-limit estimator says, against the two readings it replaces and against the truth.
SELECT
    funnel,
    step,
    stage,
    round(window_rate, 4)            AS dashboard,
    round(cohort_rate, 4)            AS cohort_30d,
    round(km_incidence, 4)           AS kaplan_meier_30d,
    round(declared_rate, 4)          AS truth,
    round(km_standard_error, 5)      AS km_error,
    round(cohort_standard_error, 5)  AS cohort_error,
    round(standard_error_ratio, 4)   AS error_ratio
FROM survival_readings
WHERE step > 1
ORDER BY position, step;
