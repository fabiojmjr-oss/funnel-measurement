-- The invariance. One of these two columns is what a service desk reports; the other is what the queue is
-- made of, and it is the same number under every order the queue can be served in.
SELECT
    discipline,
    round(mean_wait_per_demand, 6)         AS reported_mean_wait,
    round(reported_ratio, 4)               AS reported_against_fifo,
    mean_wait_per_day_of_work              AS mean_wait_per_day_of_work,
    round(invariant_ratio, 12)             AS invariant_against_fifo
FROM queue_conservation
ORDER BY discipline;
