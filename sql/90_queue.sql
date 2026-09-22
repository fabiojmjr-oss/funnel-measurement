-- The queue inside `demanda`, and the thing a prioritisation review is never told.
--
-- Waves 1 to 4 are all about one reading of one funnel being wrong. This one is not about a reading.
-- The stages of `demanda` carry a pass rate and a delay, and neither of them contains the fact that
-- makes prioritisation a decision at all: the team works on one demand at a time, so the delay of any
-- item is mostly the time it spends behind other items. Replace the delay of a stage with a server and
-- the delay stops being a property of the demand and becomes a property of the queue it sits in.
--
-- Three things are computed below, and the middle one is the wave.
--
--   * first-come-first-served, by the reflected random walk, which needs no recursion at all;
--   * two priority orders, by a recursion that is decomposed in a way the finding itself licenses;
--   * what each of them does to the waiting, per class and in total.
--
-- Nothing here is fitted. The arrival rate, the three shares, the three service means and the two
-- priority orders are all declared in sql/00_parameters.sql, and every figure is checked in
-- sql/95_queue_closed_form.sql against the algebra of M/G/1 with non-preemptive priority.

-- The demand stream. Three uniforms per demand, each from its own stream of the declared generator and
-- each indexed by the demand's own id, so the stream does not depend on the order rows are evaluated
-- in and nothing has to be drawn in sequence.
--
-- The class is assigned by inverse transform against the cumulative shares, which is the same
-- construction every other draw in this repository uses and the reason the realised shares can be
-- checked against the declared ones rather than assumed.
CREATE OR REPLACE TABLE queue_demands AS
WITH settings AS (
    SELECT
        (SELECT value FROM queue_params WHERE key = 'queue_arrivals_daily') AS arrivals_daily,
        (SELECT value FROM queue_params WHERE key = 'queue_jobs')::BIGINT   AS jobs
),
bands AS (
    -- The interval of the unit line each class owns.
    SELECT
        priority, rnk, service_mean_days, sla_days,
        sum(share) OVER (ORDER BY rnk) - share AS lo,
        sum(share) OVER (ORDER BY rnk)         AS hi
    FROM queue_classes
),
drawn AS (
    SELECT
        j                                                          AS job_id,
        lag_days(j, 1301, 1.0 / s.arrivals_daily)                  AS gap,
        u01(j, 1409)                                               AS u_class
    FROM settings s, range(1, (SELECT jobs FROM settings) + 1) t(j)
),
classed AS (
    SELECT d.job_id, d.gap, b.priority, b.rnk, b.service_mean_days, b.sla_days
    FROM drawn d
    JOIN bands b ON d.u_class >= b.lo AND d.u_class < b.hi
)
SELECT
    job_id,
    priority,
    rnk,
    sla_days,
    -- The arrival instant is the running sum of exponential gaps, which is a Poisson process.
    sum(gap) OVER (ORDER BY job_id)              AS arrival,
    lag_days(job_id, 1511, service_mean_days)    AS service
FROM classed;

-- First-come-first-served, with no recursion.
--
-- The obvious way to write this is a recursion on `depart[n] = max(depart[n-1], arrival[n]) + service[n]`,
-- and it is unnecessary. Unrolling it gives
--
--     depart[n] = cumulative_service[n] + max over j <= n of (arrival[j] - cumulative_service[j-1])
--
-- so the whole queue is a running sum and a running maximum: two window functions over a sorted table.
-- The bracket is worth naming because the next table depends on it. It is non-decreasing in n, and it
-- increases exactly when demand n arrives to find the server idle - which makes the comparison below a
-- test for an empty system that involves no subtraction of two nearly equal numbers, and therefore no
-- question about which side of zero a rounding error fell on.
CREATE OR REPLACE TABLE queue_fifo AS
WITH cumulative AS (
    SELECT
        *,
        sum(service) OVER (ORDER BY job_id)           AS work_through,
        sum(service) OVER (ORDER BY job_id) - service AS work_before
    FROM queue_demands
),
keyed AS (SELECT *, arrival - work_before AS walk FROM cumulative),
running AS (SELECT *, max(walk) OVER (ORDER BY job_id) AS reached FROM keyed),
compared AS (SELECT *, lag(reached) OVER (ORDER BY job_id) AS reached_before FROM running)
SELECT
    job_id,
    priority,
    rnk,
    sla_days,
    arrival,
    service,
    work_before + reached - arrival                          AS wait,
    work_through + reached                                   AS depart,
    (reached_before IS NULL OR reached_before <= walk)        AS found_server_idle
FROM compared;

-- The busy periods, and why they are the right unit of work.
--
-- A priority order cannot be unrolled the way first-come-first-served can, so it has to be simulated
-- one service completion at a time. Done naively that is a recursion 60,000 steps deep, and each step
-- has to find the next demand of each class.
--
-- It does not have to be one recursion. The total unfinished work in the system at any instant is the
-- same function of time under every discipline that never idles while work is waiting, because no
-- ordering of the queue creates or destroys work. So the instants at which the server goes idle are the
-- same instants under all three disciplines, and they cut the stream into intervals that do not
-- interact: at the start of each one the system is empty, whatever happened before. Each interval can
-- be simulated independently, and therefore all of them can be simulated at once.
--
-- That is the same fact as the headline result of this wave, used as an algorithm rather than stated as
-- a finding, and it is checked rather than trusted: every interval has to end at the same instant under
-- every discipline, which is asserted to machine precision in tests/assert_queue.sql.
CREATE OR REPLACE TABLE queue_periods AS
SELECT *, sum(found_server_idle::INT) OVER (ORDER BY job_id) AS busy_period
FROM queue_fifo;

-- One row per demand per priority order, with the position of the demand inside its own class and its
-- own busy period. Those two numbers are the whole state the recursion needs: within a class, a
-- non-preemptive priority order serves in arrival order, so "which demands of class k have been served"
-- is entirely described by "how many".
CREATE OR REPLACE TABLE queue_candidates AS
SELECT
    d.discipline,
    p.busy_period,
    p.job_id,
    p.priority,
    d.rnk,
    p.arrival,
    p.service,
    row_number() OVER (
        PARTITION BY d.discipline, p.busy_period, p.priority ORDER BY p.arrival
    ) AS position
FROM queue_periods p
JOIN queue_disciplines d ON d.priority = p.priority;

CREATE OR REPLACE TABLE queue_period_size AS
SELECT discipline, busy_period, count(*) AS demands
FROM queue_candidates GROUP BY 1, 2;

-- The simulation. One step per service completion, every busy period of every discipline advancing in
-- the same step.
--
-- At each completion the server takes the lowest-ranked class that has a demand waiting. Inside a busy
-- period there is always one, because the server is busy throughout by definition of the period, so the
-- branch where the server has to idle and wait for the next arrival does not exist here. That is an
-- assumption about the decomposition rather than about the queue, so it is not assumed: a demand chosen
-- before it arrived would produce a negative wait, and tests/assert_queue.sql looks for one.
CREATE OR REPLACE TABLE queue_served AS
WITH RECURSIVE simulation AS (
    SELECT
        discipline,
        busy_period,
        0::BIGINT             AS served,
        min(arrival)          AS clock,
        0::BIGINT             AS done_p1,
        0::BIGINT             AS done_p2,
        0::BIGINT             AS done_p3,
        NULL::BIGINT          AS job_id,
        NULL::VARCHAR         AS priority,
        NULL::DOUBLE          AS wait,
        NULL::DOUBLE          AS depart
    FROM queue_candidates
    GROUP BY discipline, busy_period

    UNION ALL

    SELECT discipline, busy_period, served, clock, done_p1, done_p2, done_p3,
           job_id, priority, wait, depart
    FROM (
        SELECT
            s.discipline,
            s.busy_period,
            -- Whether each class has a demand that has arrived and not yet been served.
            (c1.arrival IS NOT NULL AND c1.arrival <= s.clock) AS waiting_p1,
            (c2.arrival IS NOT NULL AND c2.arrival <= s.clock) AS waiting_p2,
            (c3.arrival IS NOT NULL AND c3.arrival <= s.clock) AS waiting_p3,
            -- The discipline is a ranking, so the choice is a comparison of ranks and not a hard-coded
            -- order. Adding a third discipline is a row in sql/00_parameters.sql and no change here.
            CASE
                WHEN waiting_p1
                 AND (NOT waiting_p2 OR c1.rnk < c2.rnk)
                 AND (NOT waiting_p3 OR c1.rnk < c3.rnk) THEN 'p1'
                WHEN waiting_p2
                 AND (NOT waiting_p3 OR c2.rnk < c3.rnk) THEN 'p2'
                ELSE 'p3'
            END                                                          AS chosen,
            CASE chosen WHEN 'p1' THEN c1.arrival WHEN 'p2' THEN c2.arrival ELSE c3.arrival END
                                                                         AS chosen_arrival,
            CASE chosen WHEN 'p1' THEN c1.service WHEN 'p2' THEN c2.service ELSE c3.service END
                                                                         AS chosen_service,
            CASE chosen WHEN 'p1' THEN c1.job_id  WHEN 'p2' THEN c2.job_id  ELSE c3.job_id  END
                                                                         AS job_id,
            greatest(s.clock, chosen_arrival)                            AS began,
            s.served + 1                                                 AS served,
            began + chosen_service                                       AS clock,
            began - chosen_arrival                                       AS wait,
            began + chosen_service                                       AS depart,
            chosen                                                       AS priority,
            s.done_p1 + (chosen = 'p1')::INT                             AS done_p1,
            s.done_p2 + (chosen = 'p2')::INT                             AS done_p2,
            s.done_p3 + (chosen = 'p3')::INT                             AS done_p3
        FROM simulation s
        JOIN queue_period_size z
          ON z.discipline = s.discipline AND z.busy_period = s.busy_period AND s.served < z.demands
        -- Three point lookups, one per class, on the position each class's pointer is at.
        LEFT JOIN queue_candidates c1
               ON c1.discipline = s.discipline AND c1.busy_period = s.busy_period
              AND c1.priority = 'p1' AND c1.position = s.done_p1 + 1
        LEFT JOIN queue_candidates c2
               ON c2.discipline = s.discipline AND c2.busy_period = s.busy_period
              AND c2.priority = 'p2' AND c2.position = s.done_p2 + 1
        LEFT JOIN queue_candidates c3
               ON c3.discipline = s.discipline AND c3.busy_period = s.busy_period
              AND c3.priority = 'p3' AND c3.position = s.done_p3 + 1
    )
)
SELECT discipline, busy_period, job_id, priority, wait, depart
FROM simulation
WHERE job_id IS NOT NULL;

-- Every demand, under every discipline, in one table.
CREATE OR REPLACE TABLE queue_waits AS
SELECT 'fifo' AS discipline, busy_period, job_id, priority, sla_days, arrival, service, wait, depart
FROM queue_periods
UNION ALL
SELECT s.discipline, s.busy_period, s.job_id, s.priority, p.sla_days, p.arrival, p.service,
       s.wait, s.depart
FROM queue_served s
JOIN queue_periods p USING (job_id);

-- What each discipline does to the waiting, per class.
--
-- `sojourn` is what the demand's owner experiences: the wait plus the handling. The service level is
-- measured against that, because nobody outside the team can see where the boundary between the two is.
--
-- The standard error is not sd/sqrt(n), and the first version of this table said it was. Waiting times in
-- a queue are not independent observations: a demand that waits a long time is one that arrived behind a
-- pile, and so did the demand after it. Treating 60,000 waits as 60,000 independent draws understates the
-- interval, and it understates it by a factor that grows with utilisation - exactly where the interval
-- matters.
--
-- What is independent is the busy period. Each one starts with an empty system, so it carries no memory
-- of the one before, and the demands in it are one cluster of correlated observations. The interval below
-- is the standard one for independent clusters: centre each demand's wait on the mean, add the centred
-- waits up **within** each busy period, and take the root of the sum of squares of those period totals.
-- Both are published, because the ratio between them is how wrong the naive interval is.
--
-- That is the third use of the same structural fact: the busy periods make the simulation cheap, they
-- make the invariance exact, and they make the interval honest.
CREATE OR REPLACE TABLE queue_readings AS
WITH centres AS (
    SELECT discipline, priority, count(*) AS demands, avg(wait) AS mean_wait,
           stddev(wait) AS wait_spread, avg(wait + service) AS mean_sojourn,
           max(sla_days) AS sla_days,
           count(*) FILTER (WHERE wait + service <= sla_days) / count(*)::DOUBLE AS sla_met,
           -- What the service level would be if nothing ever waited at all. Scheduling cannot beat this,
           -- because it cannot make the handling of a demand shorter.
           count(*) FILTER (WHERE service <= sla_days) / count(*)::DOUBLE AS sla_met_without_waiting
    FROM queue_waits
    GROUP BY 1, 2
),
periods AS (
    SELECT w.discipline, w.priority, w.busy_period, sum(w.wait - c.mean_wait) AS centred_total
    FROM queue_waits w
    JOIN centres c ON c.discipline = w.discipline AND c.priority = w.priority
    GROUP BY 1, 2, 3
),
clustered AS (
    SELECT discipline, priority, count(*) AS busy_periods,
           sqrt(sum(centred_total * centred_total)) AS root_of_squared_totals
    FROM periods
    GROUP BY 1, 2
)
SELECT
    c.discipline,
    c.priority,
    k.label,
    k.rnk                                            AS declared_rank,
    c.demands,
    p.busy_periods,
    c.mean_wait,
    c.wait_spread / sqrt(c.demands)                  AS naive_standard_error,
    p.root_of_squared_totals / c.demands             AS wait_standard_error,
    (p.root_of_squared_totals / c.demands) / (c.wait_spread / sqrt(c.demands))
                                                     AS standard_error_inflation,
    c.mean_sojourn,
    c.sla_days,
    c.sla_met,
    c.sla_met_without_waiting
FROM centres c
JOIN clustered p ON p.discipline = c.discipline AND p.priority = c.priority
JOIN queue_classes k ON k.priority = c.priority
ORDER BY c.discipline, k.rnk;

-- The two totals, and the whole argument of this wave is the difference between them.
--
-- `mean_wait_per_demand` weights every demand equally, which is what a service desk reports and what a
-- backlog-age chart shows. `mean_wait_per_day_of_work` weights each demand by the handling time it
-- brings, which is what the queue is actually made of and what nobody reports.
--
-- The second one has an exact invariance behind it. The area under the unfinished-work curve over a busy
-- period is the same under every work-conserving discipline, and each demand contributes
-- `service * wait + service^2 / 2` to it. The second term does not depend on the order, so
-- `sum(service * wait)` cannot depend on the order either - not approximately, and not in expectation,
-- but in every realisation.
CREATE OR REPLACE TABLE queue_totals AS
WITH centres AS (
    SELECT
        discipline,
        count(*)                           AS demands,
        avg(wait)                          AS mean_wait_per_demand,
        sum(service * wait)                AS work_weighted_wait,
        sum(service)                       AS work,
        sum(service * wait) / sum(service) AS mean_wait_per_day_of_work,
        max(depart)                        AS ends_at
    FROM queue_waits
    GROUP BY 1
),
periods AS (
    -- The same clustering, on the work-weighted ratio rather than on the plain mean.
    SELECT w.discipline, w.busy_period,
           sum(w.service * (w.wait - c.mean_wait_per_day_of_work)) AS centred_total
    FROM queue_waits w
    JOIN centres c ON c.discipline = w.discipline
    GROUP BY 1, 2
),
clustered AS (
    SELECT discipline, sqrt(sum(centred_total * centred_total)) AS root_of_squared_totals
    FROM periods GROUP BY 1
)
SELECT
    c.discipline,
    c.demands,
    c.mean_wait_per_demand,
    c.work_weighted_wait,
    c.mean_wait_per_day_of_work,
    p.root_of_squared_totals / c.work AS work_weighted_standard_error,
    c.ends_at
FROM centres c
JOIN clustered p ON p.discipline = c.discipline
ORDER BY c.discipline;

-- Utilisation, swept.
--
-- One parameter moves: the arrival instants are all multiplied by a constant, which changes the arrival
-- rate and nothing else. The same demands arrive in the same order with the same handling times, so the
-- comparison is comparative statics rather than nine separate experiments. The constant is chosen so
-- that the realised utilisation of each point lands exactly on the declared grid value, which
-- tests/assert_queue.sql checks before reading anything off the sweep.
CREATE OR REPLACE TABLE queue_sweep_input AS
WITH prefix AS (
    SELECT * FROM queue_demands
    WHERE job_id <= (SELECT value FROM queue_params WHERE key = 'queue_sweep_jobs')::BIGINT
),
base AS (SELECT sum(service) / max(arrival) AS utilisation FROM prefix),
grid(utilisation) AS (
    VALUES (0.40), (0.50), (0.60), (0.70), (0.78), (0.85), (0.90), (0.95), (0.98)
)
SELECT
    g.utilisation,
    p.job_id,
    p.priority,
    p.rnk,
    p.sla_days,
    p.arrival * (b.utilisation / g.utilisation) AS arrival,
    p.service
FROM grid g, prefix p, base b;

CREATE OR REPLACE TABLE queue_sweep_fifo AS
WITH cumulative AS (
    SELECT
        *,
        sum(service) OVER (PARTITION BY utilisation ORDER BY job_id)           AS work_through,
        sum(service) OVER (PARTITION BY utilisation ORDER BY job_id) - service AS work_before
    FROM queue_sweep_input
),
keyed AS (SELECT *, arrival - work_before AS walk FROM cumulative),
running AS (SELECT *, max(walk) OVER (PARTITION BY utilisation ORDER BY job_id) AS reached FROM keyed),
compared AS (
    SELECT *, lag(reached) OVER (PARTITION BY utilisation ORDER BY job_id) AS reached_before FROM running
)
SELECT
    utilisation, job_id, priority, rnk, sla_days, arrival, service,
    work_before + reached - arrival                     AS wait,
    work_through + reached                              AS depart,
    (reached_before IS NULL OR reached_before <= walk)   AS found_server_idle,
    sum((reached_before IS NULL OR reached_before <= walk)::INT)
        OVER (PARTITION BY utilisation ORDER BY job_id) AS busy_period
FROM compared;

-- The priority orders are swept over three of those utilisations rather than all nine, and the reason is
-- cost rather than taste: a busy period at 0.98 contains thousands of demands, the recursion is as deep as
-- the longest busy period, and the whole sweep would take longer than everything else in this repository
-- put together. Three points spanning low, middle and high utilisation are enough for what the sweep is
-- for, which is to show the invariance is not a property of one utilisation. The declared 0.78 is covered
-- at full length by `queue_totals` above, and the dense grid carries the shape - which, by the invariance,
-- is the shape for every discipline.
CREATE OR REPLACE TABLE queue_sweep_candidates AS
SELECT
    d.discipline,
    f.utilisation,
    f.busy_period,
    f.job_id,
    f.priority,
    d.rnk,
    f.arrival,
    f.service,
    row_number() OVER (
        PARTITION BY d.discipline, f.utilisation, f.busy_period, f.priority ORDER BY f.arrival
    ) AS position
FROM queue_sweep_fifo f
JOIN queue_disciplines d ON d.priority = f.priority
WHERE f.utilisation IN (0.50, 0.70, 0.85);

CREATE OR REPLACE TABLE queue_sweep_size AS
SELECT discipline, utilisation, busy_period, count(*) AS demands
FROM queue_sweep_candidates GROUP BY 1, 2, 3;

CREATE OR REPLACE TABLE queue_sweep_served AS
WITH RECURSIVE simulation AS (
    SELECT
        discipline, utilisation, busy_period,
        0::BIGINT AS served, min(arrival) AS clock,
        0::BIGINT AS done_p1, 0::BIGINT AS done_p2, 0::BIGINT AS done_p3,
        NULL::BIGINT AS job_id, NULL::VARCHAR AS priority, NULL::DOUBLE AS wait
    FROM queue_sweep_candidates
    GROUP BY discipline, utilisation, busy_period

    UNION ALL

    SELECT discipline, utilisation, busy_period, served, clock, done_p1, done_p2, done_p3,
           job_id, priority, wait
    FROM (
        SELECT
            s.discipline, s.utilisation, s.busy_period,
            (c1.arrival IS NOT NULL AND c1.arrival <= s.clock) AS waiting_p1,
            (c2.arrival IS NOT NULL AND c2.arrival <= s.clock) AS waiting_p2,
            (c3.arrival IS NOT NULL AND c3.arrival <= s.clock) AS waiting_p3,
            CASE
                WHEN waiting_p1
                 AND (NOT waiting_p2 OR c1.rnk < c2.rnk)
                 AND (NOT waiting_p3 OR c1.rnk < c3.rnk) THEN 'p1'
                WHEN waiting_p2
                 AND (NOT waiting_p3 OR c2.rnk < c3.rnk) THEN 'p2'
                ELSE 'p3'
            END                                                          AS chosen,
            CASE chosen WHEN 'p1' THEN c1.arrival WHEN 'p2' THEN c2.arrival ELSE c3.arrival END
                                                                         AS chosen_arrival,
            CASE chosen WHEN 'p1' THEN c1.service WHEN 'p2' THEN c2.service ELSE c3.service END
                                                                         AS chosen_service,
            CASE chosen WHEN 'p1' THEN c1.job_id  WHEN 'p2' THEN c2.job_id  ELSE c3.job_id  END
                                                                         AS job_id,
            greatest(s.clock, chosen_arrival)                            AS began,
            s.served + 1                                                 AS served,
            began + chosen_service                                        AS clock,
            began - chosen_arrival                                        AS wait,
            chosen                                                       AS priority,
            s.done_p1 + (chosen = 'p1')::INT                              AS done_p1,
            s.done_p2 + (chosen = 'p2')::INT                              AS done_p2,
            s.done_p3 + (chosen = 'p3')::INT                              AS done_p3
        FROM simulation s
        JOIN queue_sweep_size z
          ON z.discipline = s.discipline AND z.utilisation = s.utilisation
         AND z.busy_period = s.busy_period AND s.served < z.demands
        LEFT JOIN queue_sweep_candidates c1
               ON c1.discipline = s.discipline AND c1.utilisation = s.utilisation
              AND c1.busy_period = s.busy_period AND c1.priority = 'p1'
              AND c1.position = s.done_p1 + 1
        LEFT JOIN queue_sweep_candidates c2
               ON c2.discipline = s.discipline AND c2.utilisation = s.utilisation
              AND c2.busy_period = s.busy_period AND c2.priority = 'p2'
              AND c2.position = s.done_p2 + 1
        LEFT JOIN queue_sweep_candidates c3
               ON c3.discipline = s.discipline AND c3.utilisation = s.utilisation
              AND c3.busy_period = s.busy_period AND c3.priority = 'p3'
              AND c3.position = s.done_p3 + 1
    )
)
SELECT discipline, utilisation, job_id, priority, wait
FROM simulation
WHERE job_id IS NOT NULL;

CREATE OR REPLACE TABLE queue_sweep AS
WITH every_discipline AS (
    SELECT utilisation, 'fifo' AS discipline, busy_period, job_id, priority, service, wait
    FROM queue_sweep_fifo
    UNION ALL
    SELECT s.utilisation, s.discipline, f.busy_period, s.job_id, s.priority, f.service, s.wait
    FROM queue_sweep_served s
    JOIN queue_sweep_fifo f ON f.utilisation = s.utilisation AND f.job_id = s.job_id
),
centres AS (
    SELECT
        utilisation, discipline,
        count(*)                              AS demands,
        avg(wait)                             AS mean_wait_per_demand,
        sum(service * wait)                   AS work_weighted_wait,
        sum(service)                          AS work,
        sum(service * wait) / sum(service)    AS mean_wait_per_day_of_work
    FROM every_discipline
    GROUP BY 1, 2
),
periods AS (
    SELECT e.utilisation, e.discipline, e.busy_period,
           sum(e.service * (e.wait - c.mean_wait_per_day_of_work)) AS centred_total
    FROM every_discipline e
    JOIN centres c ON c.utilisation = e.utilisation AND c.discipline = e.discipline
    GROUP BY 1, 2, 3
),
clustered AS (
    SELECT utilisation, discipline, count(*) AS busy_periods,
           sqrt(sum(centred_total * centred_total)) AS root_of_squared_totals
    FROM periods GROUP BY 1, 2
)
SELECT
    c.utilisation,
    c.discipline,
    c.demands,
    p.busy_periods,
    c.mean_wait_per_demand,
    c.work_weighted_wait,
    c.mean_wait_per_day_of_work,
    p.root_of_squared_totals / c.work AS work_weighted_standard_error
FROM centres c
JOIN clustered p ON p.utilisation = c.utilisation AND p.discipline = c.discipline
ORDER BY c.utilisation, c.discipline;

-- What a quarterly review could have concluded from one slice of this, which is the only thing a real
-- operation ever has.
--
-- The stream is cut into consecutive slices of the declared length and each slice is read on its own: the
-- mean wait of the demands that arrived in it, and the interval four standard errors wide that a reviewer
-- would have drawn around it with sd/sqrt(n).
--
-- The slices are the control the reviewer never has. Nothing changes between them - same arrival rate,
-- same service times, same discipline, same utilisation - so the spread of their means **is** the standard
-- deviation of a single slice's mean, measured rather than estimated. Comparing that against the interval
-- the reviewer would have drawn says how wrong the interval is, and it is the same mistake as the naive
-- standard error in `queue_readings`, seen from the side of somebody who has one quarter of data and no
-- reason to suspect it.
CREATE OR REPLACE TABLE queue_measurability AS
WITH settings AS (SELECT (SELECT value FROM queue_params WHERE key = 'queue_slice_days') AS slice_days),
sliced AS (
    SELECT floor(arrival / s.slice_days)::BIGINT AS slice, wait
    FROM queue_periods, settings s
),
per_slice AS (
    SELECT slice, count(*) AS demands, avg(wait) AS mean_wait,
           stddev(wait) / sqrt(count(*)) AS naive_standard_error
    FROM sliced GROUP BY 1
    HAVING count(*) > 30
),
summarised AS (
    SELECT
        count(*)                   AS slices,
        avg(demands)               AS mean_demands_per_slice,
        avg(mean_wait)             AS mean_of_slice_means,
        stddev(mean_wait)          AS spread_of_slice_means,
        min(mean_wait)             AS lowest_slice_mean,
        max(mean_wait)             AS highest_slice_mean,
        avg(naive_standard_error)  AS mean_naive_standard_error
    FROM per_slice
)
SELECT
    *,
    4.0 * mean_naive_standard_error                       AS naive_half_width,
    4.0 * spread_of_slice_means                           AS honest_half_width,
    4.0 * mean_naive_standard_error / mean_of_slice_means  AS naive_relative_half_width,
    spread_of_slice_means / mean_naive_standard_error      AS interval_understated_by,
    highest_slice_mean / lowest_slice_mean                 AS widest_pair_of_readings
FROM summarised;

-- The same queue read at three run lengths, at three utilisations.
--
-- The closed forms in sql/95_queue_closed_form.sql are steady-state limits, and a finite run is not the
-- limit. How finite matters depends violently on utilisation: what makes the mean wait large near capacity
-- is a small number of very long busy periods, so as the server fills up the number of *independent*
-- observations in a run collapses even though the number of demands does not. At 0.98 one busy period
-- holds a fifth of this entire stream.
--
-- The direction is the part worth publishing. A run that is too short does not scatter around the truth,
-- it reads **low**, because the long busy periods that carry the mean are the ones a short run is least
-- likely to contain. So the quantity a capacity review most wants - how bad does it get when we are nearly
-- full - is the one a finite observation is least able to report, and the error is not conservative.
--
-- First-come-first-served only, because by the invariance the work-weighted mean is the same number for
-- every discipline and this table is about the length of the run rather than about the order of the queue.
CREATE OR REPLACE TABLE queue_run_length AS
WITH base AS (SELECT sum(service) / max(arrival) AS utilisation FROM queue_demands),
grid(utilisation) AS (VALUES (0.78), (0.95), (0.98)),
lengths(demands) AS (VALUES (5000), (20000), (60000)),
scaled AS (
    SELECT
        g.utilisation, l.demands AS run_length, d.job_id, d.service,
        d.arrival * (b.utilisation / g.utilisation) AS arrival
    FROM grid g, lengths l, base b, queue_demands d
    WHERE d.job_id <= l.demands
),
cumulative AS (
    SELECT *,
        sum(service) OVER (PARTITION BY utilisation, run_length ORDER BY job_id) - service AS work_before
    FROM scaled
),
keyed AS (SELECT *, arrival - work_before AS walk FROM cumulative),
running AS (
    SELECT *, max(walk) OVER (PARTITION BY utilisation, run_length ORDER BY job_id) AS reached FROM keyed
),
compared AS (
    SELECT *, lag(reached) OVER (PARTITION BY utilisation, run_length ORDER BY job_id) AS reached_before
    FROM running
),
waited AS (
    SELECT
        utilisation, run_length, service,
        work_before + reached - arrival AS wait,
        sum((reached_before IS NULL OR reached_before <= walk)::INT)
            OVER (PARTITION BY utilisation, run_length ORDER BY job_id) AS busy_period
    FROM compared
),
sized AS (SELECT *, count(*) OVER (PARTITION BY utilisation, run_length, busy_period) AS period_size FROM waited),
centres AS (
    SELECT utilisation, run_length, count(*) AS demands,
           count(DISTINCT busy_period) AS busy_periods,
           max(period_size) AS biggest_busy_period,
           sum(service) AS work,
           sum(service * wait) / sum(service) AS mean_wait_per_day_of_work
    FROM sized GROUP BY 1, 2
),
periods AS (
    SELECT s.utilisation, s.run_length, s.busy_period,
           sum(s.service * (s.wait - c.mean_wait_per_day_of_work)) AS centred_total
    FROM sized s
    JOIN centres c ON c.utilisation = s.utilisation AND c.run_length = s.run_length
    GROUP BY 1, 2, 3
),
clustered AS (
    SELECT utilisation, run_length, sqrt(sum(centred_total * centred_total)) AS root_of_squared_totals
    FROM periods GROUP BY 1, 2
),
moments AS (SELECT avg(service) AS service_mean, avg(service * service) AS second_moment FROM queue_demands)
SELECT
    c.utilisation,
    c.run_length,
    c.busy_periods,
    c.biggest_busy_period,
    c.biggest_busy_period / c.demands::DOUBLE                       AS biggest_share_of_run,
    c.mean_wait_per_day_of_work,
    p.root_of_squared_totals / c.work                               AS work_weighted_standard_error,
    (c.utilisation / m.service_mean) * m.second_moment / 2.0 / (1.0 - c.utilisation) AS derived_wait,
    c.mean_wait_per_day_of_work
        / ((c.utilisation / m.service_mean) * m.second_moment / 2.0 / (1.0 - c.utilisation))
                                                                    AS ratio_to_derivation
FROM centres c
JOIN clustered p ON p.utilisation = c.utilisation AND p.run_length = c.run_length
CROSS JOIN moments m
ORDER BY c.utilisation, c.run_length;
