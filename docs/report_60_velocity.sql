-- How each funnel's speed reads, against how fast it is. The two rankings are the finding.
SELECT
    funnel,
    arrivals_growth_daily          AS growth_per_day,
    stage,
    round(declared_mean, 1)        AS actually_takes_days,
    round(naive_mean, 2)           AS reads_as_days,
    round(naive_over_declared, 3)  AS reads_over_actual,
    round(restricted_mean, 2)      AS restricted_30d,
    rank_actually_slowest          AS is_slowest,
    rank_reads_slowest             AS reads_slowest
FROM speed_ranking
ORDER BY declared_mean DESC;
