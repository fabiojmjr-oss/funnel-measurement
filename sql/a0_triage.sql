-- The label the queue actually serves.
--
-- Wave 5's queue serves the class. This one serves the ticket. The demand still takes as long to handle as
-- it always did and its delay still costs what it always cost - the only thing that changes is which line
-- it stands in, and that is decided by somebody at the counter with less information than the demand has.
--
-- Two directions of error, and they behave nothing alike. A genuinely critical demand labelled `melhoria`
-- goes to the back and waits like a `melhoria`: rare, and ruinous for that demand. A routine demand
-- labelled `critico` waits less than it should, which costs it nothing - but it raises the utilisation of
-- the top class, and the utilisation of the top class is the only thing standing between the genuinely
-- critical demands and everybody else.
--
-- The recursion below is the same recursion as sql/90_queue.sql with one column changed, and SQL has no way
-- to parameterise a recursive term over which column to serve by, so it appears twice. That duplication is
-- not left on trust: the busy periods of this simulation have to end at the same instants as wave 5's, and
-- its work-weighted total has to be the same number, both asserted to machine precision in
-- tests/assert_triage.sql. An independent second implementation that has to agree with the first on every
-- shared quantity is a better control than a shared one that cannot disagree.

-- The label, by inverse transform on the demand's own row of the declared matrix.
CREATE OR REPLACE TABLE triage_assignment AS
WITH bands AS (
    -- The interval of the unit line each label owns, within the row of the true class.
    SELECT
        t.true_priority,
        t.assigned_priority,
        c.rnk                                                                    AS assigned_rank,
        sum(t.probability) OVER (PARTITION BY t.true_priority ORDER BY c.rnk) - t.probability AS lo,
        sum(t.probability) OVER (PARTITION BY t.true_priority ORDER BY c.rnk)                 AS hi
    FROM queue_triage t
    JOIN queue_classes c ON c.priority = t.assigned_priority
)
SELECT
    d.job_id,
    d.priority                AS true_priority,
    b.assigned_priority,
    b.assigned_rank,
    d.arrival,
    d.service,
    d.sla_days
FROM queue_demands d
JOIN bands b
  ON b.true_priority = d.priority
 AND u01(d.job_id, 1613) >= b.lo
 AND u01(d.job_id, 1613) <  b.hi;

-- The same busy periods. They are the same instants because no relabelling of the queue can change how
-- much work is in it, which is the fact wave 5 is about - so the decomposition carries over unchanged and
-- the assertion that it does is a test of wave 5's claim rather than a convenience of wave 6's code.
CREATE OR REPLACE TABLE triage_candidates AS
SELECT
    p.busy_period,
    a.job_id,
    a.true_priority,
    a.assigned_priority,
    a.assigned_rank                                       AS rnk,
    a.arrival,
    a.service,
    row_number() OVER (
        PARTITION BY p.busy_period, a.assigned_priority ORDER BY a.arrival
    ) AS position
FROM triage_assignment a
JOIN queue_periods p ON p.job_id = a.job_id;

CREATE OR REPLACE TABLE triage_period_size AS
SELECT busy_period, count(*) AS demands FROM triage_candidates GROUP BY 1;

CREATE OR REPLACE TABLE triage_served AS
WITH RECURSIVE simulation AS (
    SELECT
        busy_period,
        0::BIGINT     AS served,
        min(arrival)  AS clock,
        0::BIGINT     AS done_p1,
        0::BIGINT     AS done_p2,
        0::BIGINT     AS done_p3,
        NULL::BIGINT  AS job_id,
        NULL::VARCHAR AS assigned_priority,
        NULL::DOUBLE  AS wait,
        NULL::DOUBLE  AS depart
    FROM triage_candidates
    GROUP BY busy_period

    UNION ALL

    SELECT busy_period, served, clock, done_p1, done_p2, done_p3,
           job_id, assigned_priority, wait, depart
    FROM (
        SELECT
            s.busy_period,
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
            began + chosen_service                                       AS clock,
            began - chosen_arrival                                       AS wait,
            began + chosen_service                                       AS depart,
            chosen                                                       AS assigned_priority,
            s.done_p1 + (chosen = 'p1')::INT                             AS done_p1,
            s.done_p2 + (chosen = 'p2')::INT                             AS done_p2,
            s.done_p3 + (chosen = 'p3')::INT                             AS done_p3
        FROM simulation s
        JOIN triage_period_size z
          ON z.busy_period = s.busy_period AND s.served < z.demands
        LEFT JOIN triage_candidates c1
               ON c1.busy_period = s.busy_period AND c1.assigned_priority = 'p1'
              AND c1.position = s.done_p1 + 1
        LEFT JOIN triage_candidates c2
               ON c2.busy_period = s.busy_period AND c2.assigned_priority = 'p2'
              AND c2.position = s.done_p2 + 1
        LEFT JOIN triage_candidates c3
               ON c3.busy_period = s.busy_period AND c3.assigned_priority = 'p3'
              AND c3.position = s.done_p3 + 1
    )
)
SELECT busy_period, job_id, assigned_priority, wait, depart
FROM simulation
WHERE job_id IS NOT NULL;

CREATE OR REPLACE TABLE triage_waits AS
SELECT
    s.busy_period,
    s.job_id,
    a.true_priority,
    s.assigned_priority,
    a.arrival,
    a.service,
    a.sla_days,
    s.wait,
    s.depart
FROM triage_served s
JOIN triage_assignment a ON a.job_id = s.job_id;

-- What the label does to the class, and the clustered interval on it. Same construction as wave 5: centre
-- on the mean, add within each busy period, take the root of the sum of squares of the period totals.
CREATE OR REPLACE TABLE triage_readings AS
WITH by_true AS (
    SELECT 'true' AS grouping, true_priority AS priority, busy_period, wait, service, sla_days
    FROM triage_waits
    UNION ALL
    SELECT 'assigned', assigned_priority, busy_period, wait, service, sla_days FROM triage_waits
),
centres AS (
    SELECT grouping, priority, count(*) AS demands, avg(wait) AS mean_wait,
           avg(wait + service) AS mean_sojourn,
           count(*) FILTER (WHERE wait + service <= sla_days) / count(*)::DOUBLE AS sla_met
    FROM by_true GROUP BY 1, 2
),
periods AS (
    SELECT b.grouping, b.priority, b.busy_period, sum(b.wait - c.mean_wait) AS centred_total
    FROM by_true b
    JOIN centres c ON c.grouping = b.grouping AND c.priority = b.priority
    GROUP BY 1, 2, 3
),
clustered AS (
    SELECT grouping, priority, count(*) AS busy_periods,
           sqrt(sum(centred_total * centred_total)) AS root_of_squared_totals
    FROM periods GROUP BY 1, 2
)
SELECT
    c.grouping,
    c.priority,
    k.label,
    k.rnk,
    c.demands,
    c.mean_wait,
    p.root_of_squared_totals / c.demands             AS wait_standard_error,
    c.mean_sojourn,
    c.sla_met
FROM centres c
JOIN clustered p ON p.grouping = c.grouping AND p.priority = c.priority
JOIN queue_classes k ON k.priority = c.priority
ORDER BY c.grouping, k.rnk;

-- How much of each label is what it says it is, and where the rest of it came from.
--
-- The last two columns exist because of defect 12: the first draft of the README explained the top label's
-- composition with a sentence of arithmetic that was simply wrong. Every *figure* in the prose of this
-- repository is re-derived by tests/assert_published_figures.sql, and a sentence that reasons about figures
-- is not a figure. The fix is to stop reasoning in prose and publish the two quantities the sentence was
-- about, so that they are under test like everything else.
CREATE OR REPLACE TABLE triage_purity AS
WITH counted AS (
    SELECT assigned_priority, true_priority, count(*) AS demands FROM triage_waits GROUP BY 1, 2
),
totals AS (SELECT assigned_priority, sum(demands) AS labelled FROM counted GROUP BY 1)
SELECT
    c.assigned_priority,
    k.label                                     AS assigned_label,
    k.rnk,
    t.labelled,
    t.labelled / (SELECT count(*) FROM triage_waits)::DOUBLE AS share_of_all_demands,
    sum(c.demands) FILTER (WHERE c.true_priority = c.assigned_priority) / t.labelled::DOUBLE
                                                AS share_correctly_labelled,
    sum(c.demands) FILTER (WHERE c.true_priority = c.assigned_priority)
                                                AS demands_from_its_own_class,
    sum(c.demands) FILTER (WHERE c.true_priority <> c.assigned_priority)
                                                AS demands_from_other_classes
FROM counted c
JOIN totals t ON t.assigned_priority = c.assigned_priority
JOIN queue_classes k ON k.priority = c.assigned_priority
GROUP BY 1, 2, 3, 4, 5
ORDER BY k.rnk;

-- What the triage desk costs each class, against the same queue served perfectly.
CREATE OR REPLACE TABLE triage_damage AS
SELECT
    t.priority,
    k.label,
    k.rnk,
    p.mean_wait                                   AS wait_under_perfect_triage,
    t.mean_wait                                   AS wait_under_real_triage,
    t.mean_wait - p.mean_wait                     AS extra_days,
    t.mean_wait / p.mean_wait                     AS ratio,
    f.mean_wait                                   AS wait_under_no_priority,
    t.wait_standard_error,
    p.sla_met                                     AS sla_under_perfect_triage,
    t.sla_met                                     AS sla_under_real_triage
FROM triage_readings t
JOIN queue_readings p ON p.discipline = 'priority' AND p.priority = t.priority
JOIN queue_readings f ON f.discipline = 'fifo'     AND f.priority = t.priority
JOIN queue_classes k  ON k.priority = t.priority
WHERE t.grouping = 'true'
ORDER BY k.rnk;

-- And the total, which is the point.
--
-- Nothing above changed how much work arrives or how fast it is served, so wave 5's invariance has to
-- survive a triage desk that gets a third of its calls wrong. It does, exactly - which means every extra
-- day the critical class waits is a day some other class does not. A triage error is not waste. It is a
-- transfer, and it is a transfer to whoever the label sent to the front.
CREATE OR REPLACE TABLE triage_totals AS
WITH centres AS (
    SELECT
        count(*)                           AS demands,
        avg(wait)                          AS mean_wait_per_demand,
        sum(service * wait)                AS work_weighted_wait,
        sum(service)                       AS work,
        sum(service * wait) / sum(service) AS mean_wait_per_day_of_work
    FROM triage_waits
),
periods AS (
    SELECT w.busy_period,
           sum(w.service * (w.wait - c.mean_wait_per_day_of_work)) AS centred_total
    FROM triage_waits w, centres c
    GROUP BY 1
),
clustered AS (SELECT sqrt(sum(centred_total * centred_total)) AS root_of_squared_totals FROM periods)
SELECT
    'triaged' AS discipline,
    c.demands,
    c.mean_wait_per_demand,
    c.work_weighted_wait,
    c.mean_wait_per_day_of_work,
    p.root_of_squared_totals / c.work AS work_weighted_standard_error,
    (SELECT work_weighted_wait FROM queue_totals WHERE discipline = 'priority')
        AS work_weighted_under_perfect_triage,
    c.work_weighted_wait / (SELECT work_weighted_wait FROM queue_totals WHERE discipline = 'priority')
        AS ratio_to_perfect_triage
FROM centres c, clustered p;
