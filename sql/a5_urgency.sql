-- The triage desk derived on paper, and then the question it exists to answer.
--
-- Two derivations here, and they are different kinds of statement.
--
-- The first is arithmetic about the queue in sql/a0_triage.sql. Cobham's formula applies to the **labels**,
-- because the labels are what the server sorts by; a label's utilisation is the work its members bring
-- whatever class they truly belong to, and a label's service distribution is therefore a mixture. The wait
-- of a true class is then a conditional average over the labels its members land in:
--
--     W(true i)  =  sum over labels j of  P(label j | class i) * W(label j)
--
-- which is exact, and is the only place in this repository where a published figure is a composition of two
-- derivations rather than one. So it is verified against the simulation rather than assumed.
--
-- The second is not about this account at all. Wave 5 proved that no order can change the total waiting, so
-- the only thing an order does is decide who waits, and choosing well requires saying what waiting costs.
-- Given declared costs there is a unique best order, it is known in closed form, and it is not the order
-- anybody writes down.

-- Per label: how much work it brings and how variable that work is. Both are mixtures over the true classes
-- feeding it, which is the step the composition above depends on.
CREATE OR REPLACE TABLE triage_moments AS
WITH horizon AS (SELECT max(arrival) AS elapsed, count(*) AS demands FROM triage_assignment)
SELECT
    a.assigned_priority                                   AS priority,
    k.rnk,
    k.label,
    count(*)                                              AS demands,
    count(*) / (SELECT elapsed FROM horizon)              AS realised_rate,
    avg(a.service)                                        AS realised_service_mean,
    avg(a.service * a.service)                            AS realised_service_second_moment,
    sum(a.service) / (SELECT elapsed FROM horizon)        AS realised_utilisation
FROM triage_assignment a
JOIN queue_classes k ON k.priority = a.assigned_priority
GROUP BY 1, 2, 3
ORDER BY k.rnk;

CREATE OR REPLACE TABLE triage_residual AS
SELECT
    sum(realised_rate * realised_service_second_moment) / 2.0 AS residual_work,
    sum(realised_utilisation)                                 AS utilisation
FROM triage_moments;

-- Cobham on the labels.
CREATE OR REPLACE TABLE triage_label_closed_form AS
WITH ranked AS (
    SELECT
        m.priority,
        m.rnk,
        m.label,
        m.realised_utilisation,
        sum(m.realised_utilisation) OVER (ORDER BY m.rnk)                          AS through_this_rank,
        sum(m.realised_utilisation) OVER (ORDER BY m.rnk) - m.realised_utilisation AS above_this_rank
    FROM triage_moments m
)
SELECT
    r.priority,
    r.rnk,
    r.label,
    r.realised_utilisation,
    d.residual_work / ((1.0 - r.above_this_rank) * (1.0 - r.through_this_rank)) AS derived_wait,
    q.mean_wait                                                                AS simulated_wait,
    q.wait_standard_error,
    (q.mean_wait - d.residual_work / ((1.0 - r.above_this_rank) * (1.0 - r.through_this_rank)))
        / q.wait_standard_error                                                AS deviation_standard_errors
FROM ranked r, triage_residual d
JOIN triage_readings q ON q.grouping = 'assigned' AND q.priority = r.priority
ORDER BY r.rnk;

-- And the composition back onto the true classes, which is the figure the wave publishes.
CREATE OR REPLACE TABLE triage_closed_form AS
WITH composed AS (
    SELECT
        t.true_priority                                       AS priority,
        sum(t.probability * l.derived_wait)                   AS derived_wait,
        sum(t.probability)                                    AS probability_total
    FROM queue_triage t
    JOIN triage_label_closed_form l ON l.priority = t.assigned_priority
    GROUP BY 1
)
SELECT
    c.priority,
    k.rnk,
    k.label,
    c.probability_total,
    c.derived_wait,
    q.mean_wait                                       AS simulated_wait,
    q.wait_standard_error,
    (q.mean_wait - c.derived_wait) / q.wait_standard_error AS deviation_standard_errors,
    p.derived_wait                                    AS derived_under_perfect_triage,
    c.derived_wait / p.derived_wait                   AS derived_ratio
FROM composed c
JOIN triage_readings q ON q.grouping = 'true' AND q.priority = c.priority
JOIN queue_closed_form p ON p.discipline = 'priority' AND p.priority = c.priority
JOIN queue_classes k ON k.priority = c.priority
ORDER BY k.rnk;

-- The two error directions, swept one at a time, in closed form.
--
-- `over` escalates that share of every non-critical demand to the top label and mislabels no critical one.
-- `under` sends that share of the genuinely critical demands to the bottom label and escalates nobody.
-- Both are comparative statics on the declared utilisations, so neither needs a simulation - and the point
-- of sweeping them separately is that a triage desk can be improved in two directions and they are not
-- worth the same effort.
--
-- The common scale is the declared urgency. Waiting is only comparable across classes once somebody says
-- what a day of it is worth, which is the argument sql/00_parameters.sql makes when it declares the weights.
CREATE OR REPLACE TABLE escalation_sweep AS
WITH base AS (
    SELECT
        (SELECT residual_work FROM queue_residual) AS w0,
        (SELECT realised_utilisation FROM queue_moments WHERE priority = 'p1') AS r1,
        (SELECT realised_utilisation FROM queue_moments WHERE priority = 'p2') AS r2,
        (SELECT realised_utilisation FROM queue_moments WHERE priority = 'p3') AS r3,
        (SELECT realised_rate FROM queue_moments WHERE priority = 'p1') AS l1,
        (SELECT realised_rate FROM queue_moments WHERE priority = 'p2') AS l2,
        (SELECT realised_rate FROM queue_moments WHERE priority = 'p3') AS l3,
        (SELECT urgency_weight FROM queue_urgency WHERE priority = 'p1') AS c1,
        (SELECT urgency_weight FROM queue_urgency WHERE priority = 'p2') AS c2,
        (SELECT urgency_weight FROM queue_urgency WHERE priority = 'p3') AS c3
),
grid(rate) AS (VALUES (0.00), (0.05), (0.10), (0.20), (0.30), (0.50), (0.75), (1.00)),
directions(direction) AS (VALUES ('over'), ('under')),
labelled AS (
    SELECT
        d.direction,
        g.rate,
        b.*,
        -- The utilisation each label carries once the declared share has been moved.
        CASE d.direction WHEN 'over'  THEN b.r1 + g.rate * (b.r2 + b.r3)
                         ELSE (1.0 - g.rate) * b.r1 END AS u1,
        CASE d.direction WHEN 'over'  THEN (1.0 - g.rate) * b.r2 ELSE b.r2 END AS u2,
        CASE d.direction WHEN 'over'  THEN (1.0 - g.rate) * b.r3
                         ELSE b.r3 + g.rate * b.r1 END AS u3
    FROM directions d, grid g, base b
),
waits AS (
    SELECT
        *,
        w0 / (1.0 - u1)                                     AS wa1,
        w0 / ((1.0 - u1) * (1.0 - u1 - u2))                 AS wa2,
        w0 / ((1.0 - u1 - u2) * (1.0 - u1 - u2 - u3))       AS wa3
    FROM labelled
),
composed AS (
    SELECT
        direction, rate, u1, wa1, wa2, wa3, l1, l2, l3, c1, c2, c3, r1, r2, r3,
        -- Where each true class ends up.
        CASE direction WHEN 'over' THEN wa1 ELSE (1.0 - rate) * wa1 + rate * wa3 END AS w_true1,
        CASE direction WHEN 'over' THEN rate * wa1 + (1.0 - rate) * wa2 ELSE wa2 END AS w_true2,
        CASE direction WHEN 'over' THEN rate * wa1 + (1.0 - rate) * wa3 ELSE wa3 END AS w_true3
    FROM waits
)
SELECT
    direction,
    rate,
    u1                                                          AS top_label_utilisation,
    w_true1                                                     AS critical_wait,
    w_true2                                                     AS standard_wait,
    w_true3                                                     AS improvement_wait,
    w_true1 / (SELECT derived_wait FROM queue_closed_form
               WHERE discipline = 'priority' AND priority = 'p1') AS critical_ratio,
    -- Waiting weighted by what a day of it is declared to be worth, summed over the arriving demands.
    c1 * l1 * w_true1 + c2 * l2 * w_true2 + c3 * l3 * w_true3   AS weighted_waiting,
    -- And the work-weighted total, which wave 5 says nothing here can move.
    r1 * w_true1 + r2 * w_true2 + r3 * w_true3                  AS work_weighted_waiting
FROM composed
ORDER BY direction, rate;

-- Every order the queue could be served in, derived, and the rule that picks the winner without trying them.
--
-- Three classes make six orders. Each one is Cobham's formula with the utilisations accumulated in that
-- order, and each one produces a different distribution of waiting at an identical total. Weighted by the
-- declared cost of a day, one of them is best - and the rule that names it is not "most urgent first". It is
-- **most urgent per day of handling first**: rank by urgency divided by mean handling time. An order that is
-- twice as urgent but four times as slow to clear belongs second.
--
-- The six orders are enumerated rather than reasoned about, and the rule is checked against the enumeration
-- in tests/assert_urgency.sql. A rule that picks the right answer out of six candidates it was not told
-- about is a rule that has been tested.
CREATE OR REPLACE TABLE urgency_orders AS
WITH permutations(ordering, first, second, third) AS (
    VALUES ('p1 p2 p3', 'p1', 'p2', 'p3'), ('p1 p3 p2', 'p1', 'p3', 'p2'),
           ('p2 p1 p3', 'p2', 'p1', 'p3'), ('p2 p3 p1', 'p2', 'p3', 'p1'),
           ('p3 p1 p2', 'p3', 'p1', 'p2'), ('p3 p2 p1', 'p3', 'p2', 'p1')
),
placed AS (
    SELECT ordering, first AS priority, 1 AS place FROM permutations
    UNION ALL SELECT ordering, second, 2 FROM permutations
    UNION ALL SELECT ordering, third, 3 FROM permutations
),
ranked AS (
    SELECT
        p.ordering,
        p.priority,
        p.place,
        m.realised_utilisation,
        m.realised_rate,
        u.urgency_weight,
        sum(m.realised_utilisation) OVER (PARTITION BY p.ordering ORDER BY p.place) AS through,
        sum(m.realised_utilisation) OVER (PARTITION BY p.ordering ORDER BY p.place)
            - m.realised_utilisation                                               AS above
    FROM placed p
    JOIN queue_moments m ON m.priority = p.priority
    JOIN queue_urgency u ON u.priority = p.priority
),
derived AS (
    SELECT
        r.*,
        d.residual_work / ((1.0 - r.above) * (1.0 - r.through)) AS derived_wait
    FROM ranked r, queue_residual d
),
totalled AS (
    SELECT
        ordering,
        sum(urgency_weight * realised_rate * derived_wait) AS weighted_waiting,
        sum(realised_utilisation * derived_wait)           AS work_weighted_waiting,
        sum(realised_rate * derived_wait) / sum(realised_rate) AS mean_wait_per_demand
    FROM derived
    GROUP BY 1
)
SELECT
    t.*,
    t.weighted_waiting / min(t.weighted_waiting) OVER ()  AS weighted_against_best,
    t.weighted_waiting = min(t.weighted_waiting) OVER ()  AS is_best
FROM totalled t
ORDER BY t.weighted_waiting;

-- The rule itself, and how much margin the intuitive answer has.
--
-- Ranking by urgency over handling time reproduces the winning order above. The column worth reading is the
-- last one: for each adjacent pair, how many times more urgent per day the higher class would have to stop
-- being before the order should swap. Those margins are factors of two, not factors of ten, and they are
-- ratios of two numbers no escalation policy contains.
CREATE OR REPLACE TABLE urgency_rule AS
WITH scored AS (
    SELECT
        c.priority,
        c.rnk                                        AS declared_rank,
        c.label,
        u.urgency_weight,
        m.realised_service_mean,
        u.urgency_weight / m.realised_service_mean   AS cost_per_day_of_handling
    FROM queue_classes c
    JOIN queue_urgency u ON u.priority = c.priority
    JOIN queue_moments m ON m.priority = c.priority
),
ordered AS (
    SELECT *, rank() OVER (ORDER BY cost_per_day_of_handling DESC) AS rule_rank FROM scored
)
SELECT
    a.priority,
    a.label,
    a.declared_rank,
    a.rule_rank,
    a.urgency_weight,
    a.realised_service_mean,
    a.cost_per_day_of_handling,
    b.priority                                             AS next_priority,
    a.urgency_weight / b.urgency_weight                     AS declared_urgency_ratio,
    a.realised_service_mean / b.realised_service_mean       AS handling_time_ratio,
    (a.urgency_weight / b.urgency_weight)
        / (a.realised_service_mean / b.realised_service_mean) AS margin_before_the_order_swaps
FROM ordered a
LEFT JOIN ordered b ON b.rule_rank = a.rule_rank + 1
ORDER BY a.rule_rank;

-- And the sweep that shows where the intuitive order actually breaks.
--
-- The critical class's mean handling time is swept while the work it brings is held fixed, so the same
-- critical workload arrives either as many quick incidents or as a few slow ones. Utilisation does not move,
-- the other two classes do not move, and the only thing that changes is how long the top of the queue blocks
-- everything behind it.
--
-- Critical-first stops being the best order at urgency_1 * handling_2 / urgency_2 days of handling, and past
-- that point protecting the critical class costs more, in declared terms, than it is worth.
CREATE OR REPLACE TABLE urgency_sweep AS
WITH base AS (
    SELECT
        (SELECT realised_utilisation FROM queue_moments WHERE priority = 'p1') AS r1,
        (SELECT realised_utilisation FROM queue_moments WHERE priority = 'p2') AS r2,
        (SELECT realised_utilisation FROM queue_moments WHERE priority = 'p3') AS r3,
        (SELECT realised_rate FROM queue_moments WHERE priority = 'p2') AS l2,
        (SELECT realised_rate FROM queue_moments WHERE priority = 'p3') AS l3,
        (SELECT realised_service_second_moment FROM queue_moments WHERE priority = 'p2') AS s2,
        (SELECT realised_service_second_moment FROM queue_moments WHERE priority = 'p3') AS s3,
        (SELECT realised_service_mean FROM queue_moments WHERE priority = 'p2') AS m2,
        (SELECT urgency_weight FROM queue_urgency WHERE priority = 'p1') AS c1,
        (SELECT urgency_weight FROM queue_urgency WHERE priority = 'p2') AS c2,
        (SELECT urgency_weight FROM queue_urgency WHERE priority = 'p3') AS c3
),
grid(handling) AS (
    VALUES (0.50), (0.75), (1.00), (1.2380), (1.50), (2.00), (2.4000), (2.5000), (2.6000), (3.00), (4.00), (6.00)
),
parameters AS (
    SELECT
        g.handling,
        b.*,
        b.r1 / g.handling                              AS l1,
        -- An exponential of mean m has second moment 2m^2, so held utilisation makes the residual work
        -- linear in the handling time: r1 * m + the other two classes' contribution.
        (b.r1 * g.handling + b.l2 * b.s2 + b.l3 * b.s3) / 2.0 AS w0
    FROM grid g, base b
),
critical_first AS (
    SELECT
        handling, c1, c2, c3, l1, l2, l3, r1, r2, r3, w0, m2,
        w0 / (1.0 - r1)                                        AS w1,
        w0 / ((1.0 - r1) * (1.0 - r1 - r2))                    AS w2,
        w0 / ((1.0 - r1 - r2) * (1.0 - r1 - r2 - r3))          AS w3
    FROM parameters
),
standard_first AS (
    SELECT
        handling,
        w0 / ((1.0 - r2) * (1.0 - r2 - r1))                    AS w1,
        w0 / (1.0 - r2)                                        AS w2,
        w0 / ((1.0 - r2 - r1) * (1.0 - r1 - r2 - r3))          AS w3
    FROM parameters
)
SELECT
    c.handling                                                        AS critical_handling_days,
    c.l1                                                              AS critical_arrival_rate,
    c.w1                                                              AS critical_wait_critical_first,
    s.w1                                                              AS critical_wait_standard_first,
    c.c1 * c.l1 * c.w1 + c.c2 * c.l2 * c.w2 + c.c3 * c.l3 * c.w3      AS weighted_critical_first,
    c.c1 * c.l1 * s.w1 + c.c2 * c.l2 * s.w2 + c.c3 * c.l3 * s.w3      AS weighted_standard_first,
    (c.c1 * c.l1 * c.w1 + c.c2 * c.l2 * c.w2 + c.c3 * c.l3 * c.w3)
        / (c.c1 * c.l1 * s.w1 + c.c2 * c.l2 * s.w2 + c.c3 * c.l3 * s.w3)
                                                                      AS critical_first_over_standard_first,
    c.c1 / c.handling                                                 AS critical_cost_per_day_of_handling,
    c.c2 / c.m2                                                       AS standard_cost_per_day_of_handling,
    c.c1 * c.m2 / c.c2                                                AS handling_at_which_the_order_swaps
FROM critical_first c
JOIN standard_first s ON s.handling = c.handling
ORDER BY c.handling;

-- Where under-recognition makes a priority system worse than no priority system.
--
-- Over-escalation converges on first-come-first-served: label everything critical and the queue is one
-- queue again, which is exactly as good for the critical class as never having sorted it. Under-recognition
-- overshoots. Sending a share of the critical demands to the bottom is not a partial loss of the sorting, it
-- is an active misdirection, and past some rate the genuinely critical demands would have been better off in
-- an unsorted queue.
--
-- That rate is located on a grid of one percentage point rather than solved for, because the crossing is what
-- gets published and a grid can be read off the table.
CREATE OR REPLACE TABLE escalation_crossover AS
WITH base AS (
    SELECT
        (SELECT residual_work FROM queue_residual) AS w0,
        (SELECT realised_utilisation FROM queue_moments WHERE priority = 'p1') AS r1,
        (SELECT realised_utilisation FROM queue_moments WHERE priority = 'p2') AS r2,
        (SELECT utilisation FROM queue_residual) AS rho,
        (SELECT max(derived_wait) FROM queue_closed_form WHERE discipline = 'fifo') AS fifo_wait
),
grid AS (SELECT n / 100.0 AS rate FROM range(0, 101) t(n)),
waits AS (
    SELECT
        g.rate,
        b.fifo_wait,
        (1.0 - g.rate) * b.r1                                             AS u1,
        b.w0 / (1.0 - (1.0 - g.rate) * b.r1)                              AS wa1,
        b.w0 / ((1.0 - (1.0 - g.rate) * b.r1 - b.r2) * (1.0 - b.rho))     AS wa3
    FROM grid g, base b
),
composed AS (
    SELECT rate, fifo_wait, u1, (1.0 - rate) * wa1 + rate * wa3 AS critical_wait FROM waits
)
SELECT
    rate                                     AS under_recognition_rate,
    u1                                       AS top_label_utilisation,
    critical_wait,
    fifo_wait                                AS wait_with_no_priority_at_all,
    critical_wait / fifo_wait                AS critical_over_no_priority,
    critical_wait > fifo_wait                AS worse_than_no_priority
FROM composed
ORDER BY rate;

-- What the declared triage desk costs, on the one scale that makes the three classes comparable, against
-- what choosing the wrong order costs.
--
-- These are the two levers a prioritisation review can pull, and they are not worth the same. The review
-- spends its time on the order.
CREATE OR REPLACE TABLE triage_cost AS
WITH weighted AS (
    SELECT
        sum(u.urgency_weight * m.realised_rate * c.derived_wait)                 AS weighted_real,
        sum(u.urgency_weight * m.realised_rate * c.derived_under_perfect_triage) AS weighted_perfect
    FROM triage_closed_form c
    JOIN queue_moments m ON m.priority = c.priority
    JOIN queue_urgency u ON u.priority = c.priority
),
orders AS (
    SELECT
        min(weighted_waiting)                                              AS best_order,
        max(weighted_waiting)                                              AS worst_order,
        min(weighted_waiting) FILTER (WHERE NOT is_best)                   AS second_best_order
    FROM urgency_orders
)
SELECT
    w.weighted_perfect,
    w.weighted_real,
    w.weighted_real / w.weighted_perfect       AS cost_of_imperfect_triage,
    o.second_best_order / o.best_order         AS cost_of_the_next_best_order,
    o.worst_order / o.best_order               AS cost_of_the_worst_order,
    (SELECT derived_ratio FROM triage_closed_form WHERE priority = 'p1')
                                               AS cost_of_imperfect_triage_to_the_critical_class
FROM weighted w, orders o;
