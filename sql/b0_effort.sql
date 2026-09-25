-- The triage desk consumes the capacity it protects.
--
-- Wave 6 gave the desk a declared error rate and charged nothing for it. This wave charges. Each look at a
-- demand costs the server `look_days`, the label is the mode of `looks` independent looks, and the server
-- that does the looking is the same server that does the work. So accuracy is bought with the only thing
-- the priority order had to allocate.
--
-- Two derivations, both exact.
--
-- The first is the confusion matrix. With `looks` independent looks, each reporting the true class with
-- probability q and otherwise picking uniformly between the other two, the distribution of the vote counts
-- is multinomial and the label is a deterministic function of those counts. So the matrix is a finite sum
-- over compositions of `looks` into three parts - arithmetic, not simulation. It is checked against a draw
-- from the declared generator anyway, because a derivation nobody tested is a derivation nobody ran.
--
-- The second is the queue. Wave 5's and wave 6's machinery is reused unchanged: Cobham on the labels, then
-- the conditional average over labels. The only new input is that every service time grows by
-- `looks * look_days`, which moves the arrival rate's product with it, the residual work, and the
-- utilisation - all three of which the formulas already contain.

-- The matrix, derived.
--
-- An even number of looks can tie, and the tie-break decides the label. That is not a detail: it is the
-- reason accuracy is not monotone in effort, which is the first result of this wave.
CREATE OR REPLACE TABLE effort_confusion AS
WITH settings AS (
    SELECT
        (SELECT value FROM queue_effort WHERE key = 'look_accuracy')  AS accuracy,
        (SELECT value FROM queue_effort WHERE key = 'max_looks')::INTEGER AS max_looks
),
grid(looks) AS (VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8)),
-- Every way `looks` votes can fall into three classes.
compositions AS (
    SELECT g.looks, a.n AS votes_p1, b.n AS votes_p2, g.looks - a.n - b.n AS votes_p3
    FROM grid g,
         range(0, (SELECT max_looks FROM settings) + 1) a(n),
         range(0, (SELECT max_looks FROM settings) + 1) b(n)
    WHERE a.n + b.n <= g.looks
),
ranked AS (SELECT rnk AS true_rank, priority AS true_priority FROM queue_classes),
weighted AS (
    SELECT
        c.looks,
        r.true_rank,
        r.true_priority,
        c.votes_p1, c.votes_p2, c.votes_p3,
        -- The multinomial coefficient, exactly.
        (factorial(c.looks::INTEGER)
            / (factorial(c.votes_p1::INTEGER) * factorial(c.votes_p2::INTEGER)
               * factorial(c.votes_p3::INTEGER)))::DOUBLE AS arrangements,
        CASE r.true_rank WHEN 1 THEN s.accuracy ELSE (1.0 - s.accuracy) / 2.0 END AS chance_p1,
        CASE r.true_rank WHEN 2 THEN s.accuracy ELSE (1.0 - s.accuracy) / 2.0 END AS chance_p2,
        CASE r.true_rank WHEN 3 THEN s.accuracy ELSE (1.0 - s.accuracy) / 2.0 END AS chance_p3
    FROM compositions c, ranked r, settings s
),
outcomes AS (
    SELECT
        looks, true_rank, true_priority, votes_p1, votes_p2, votes_p3,
        arrangements * pow(chance_p1, votes_p1) * pow(chance_p2, votes_p2)
            * pow(chance_p3, votes_p3) AS probability,
        -- The mode, under each declared tie-break.
        CASE WHEN votes_p1 >= votes_p2 AND votes_p1 >= votes_p3 THEN 1
             WHEN votes_p2 >= votes_p3 THEN 2 ELSE 3 END AS urgent_rank,
        CASE WHEN votes_p3 >= votes_p1 AND votes_p3 >= votes_p2 THEN 3
             WHEN votes_p2 >= votes_p1 THEN 2 ELSE 1 END AS lenient_rank
    FROM weighted
),
long AS (
    SELECT looks, 'urgent'  AS tie_break, true_rank, true_priority, urgent_rank  AS assigned_rank, probability FROM outcomes
    UNION ALL
    SELECT looks, 'lenient',              true_rank, true_priority, lenient_rank,                 probability FROM outcomes
)
SELECT
    l.looks,
    l.tie_break,
    l.true_priority,
    l.true_rank,
    k.priority                AS assigned_priority,
    l.assigned_rank,
    sum(l.probability)        AS probability
FROM long l
JOIN queue_classes k ON k.rnk = l.assigned_rank
GROUP BY 1, 2, 3, 4, 5, 6
HAVING sum(l.probability) > 0
ORDER BY l.looks, l.tie_break, l.true_rank, l.assigned_rank;

-- The same matrix, drawn.
--
-- One uniform per look from the declared generator, inverse-transformed against the three outcomes of a
-- single look, then the mode taken the same way. This exists to catch an error in the combinatorics above,
-- which is the kind of error that produces a plausible matrix whose rows still sum to one.
CREATE OR REPLACE TABLE effort_confusion_draw AS
WITH settings AS (
    SELECT
        (SELECT value FROM queue_effort WHERE key = 'look_accuracy')    AS accuracy,
        (SELECT value FROM queue_effort WHERE key = 'declared_looks')::INTEGER AS looks
),
-- The two classes a look can wrongly report, in rank order, for each true class.
others AS (
    SELECT t.rnk AS true_rank, min(o.rnk) AS first_other, max(o.rnk) AS second_other
    FROM queue_classes t JOIN queue_classes o ON o.rnk <> t.rnk
    GROUP BY 1
),
looked AS (
    SELECT
        d.job_id,
        d.priority                                       AS true_priority,
        k.rnk                                            AS true_rank,
        l.i                                              AS look_index,
        u01(d.job_id * 16 + l.i, 1709)                   AS draw
    FROM queue_demands d
    JOIN queue_classes k ON k.priority = d.priority
    CROSS JOIN range(1, (SELECT looks FROM settings) + 1) l(i)
),
reported AS (
    SELECT
        l.job_id, l.true_priority, l.true_rank,
        CASE
            WHEN l.draw < s.accuracy THEN l.true_rank
            WHEN l.draw < s.accuracy + (1.0 - s.accuracy) / 2.0 THEN o.first_other
            ELSE o.second_other
        END AS reported_rank
    FROM looked l, settings s
    JOIN others o ON o.true_rank = l.true_rank
),
counted AS (
    SELECT
        job_id, true_priority, true_rank,
        count(*) FILTER (WHERE reported_rank = 1) AS votes_p1,
        count(*) FILTER (WHERE reported_rank = 2) AS votes_p2,
        count(*) FILTER (WHERE reported_rank = 3) AS votes_p3
    FROM reported
    GROUP BY 1, 2, 3
),
moded AS (
    SELECT
        *,
        CASE WHEN votes_p1 >= votes_p2 AND votes_p1 >= votes_p3 THEN 1
             WHEN votes_p2 >= votes_p3 THEN 2 ELSE 3 END AS urgent_rank,
        CASE WHEN votes_p3 >= votes_p1 AND votes_p3 >= votes_p2 THEN 3
             WHEN votes_p2 >= votes_p1 THEN 2 ELSE 1 END AS lenient_rank
    FROM counted
),
long AS (
    SELECT 'urgent'  AS tie_break, true_priority, true_rank, urgent_rank  AS assigned_rank FROM moded
    UNION ALL
    SELECT 'lenient',              true_priority, true_rank, lenient_rank                  FROM moded
)
SELECT
    l.tie_break,
    l.true_priority,
    l.true_rank,
    k.priority                                                       AS assigned_priority,
    l.assigned_rank,
    count(*)                                                          AS demands,
    count(*) / sum(count(*)) OVER (PARTITION BY l.tie_break, l.true_rank)::DOUBLE AS drawn_probability
FROM long l
JOIN queue_classes k ON k.rnk = l.assigned_rank
GROUP BY 1, 2, 3, 4, 5
ORDER BY l.tie_break, l.true_rank, l.assigned_rank;

-- What the effort costs the server.
--
-- Every service time grows by `looks * look_days`. For a random variable S and a constant c,
-- E[(S+c)^2] = E[S^2] + 2c*E[S] + c^2, so the inflated second moment is exact rather than re-measured.
CREATE OR REPLACE TABLE effort_capacity AS
WITH settings AS (SELECT (SELECT value FROM queue_effort WHERE key = 'look_days') AS look_days),
grid(looks) AS (VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8)),
per_class AS (
    SELECT
        g.looks,
        m.priority,
        m.rnk,
        m.realised_rate,
        g.looks * s.look_days                                              AS added_service,
        m.realised_service_mean + g.looks * s.look_days                    AS service_mean,
        m.realised_service_second_moment
            + 2.0 * g.looks * s.look_days * m.realised_service_mean
            + pow(g.looks * s.look_days, 2)                                AS service_second_moment,
        m.realised_rate * (m.realised_service_mean + g.looks * s.look_days) AS utilisation
    FROM grid g, settings s
    JOIN queue_moments m ON TRUE
)
SELECT
    looks,
    max(added_service)                                        AS triage_days_per_demand,
    sum(utilisation)                                          AS utilisation,
    sum(realised_rate * service_second_moment) / 2.0          AS residual_work,
    sum(realised_rate * service_mean) / sum(realised_rate)    AS mean_service,
    -- What the same queue would wait with no priority order at all, at this utilisation.
    (sum(realised_rate * service_second_moment) / 2.0) / (1.0 - sum(utilisation)) AS wait_without_priority
FROM per_class
GROUP BY looks
ORDER BY looks;

CREATE OR REPLACE TABLE effort_capacity_by_class AS
WITH settings AS (SELECT (SELECT value FROM queue_effort WHERE key = 'look_days') AS look_days),
grid(looks) AS (VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8))
SELECT
    g.looks,
    m.priority,
    m.rnk,
    m.realised_rate,
    m.realised_service_mean + g.looks * s.look_days                     AS service_mean,
    m.realised_service_second_moment
        + 2.0 * g.looks * s.look_days * m.realised_service_mean
        + pow(g.looks * s.look_days, 2)                                 AS service_second_moment,
    m.realised_rate * (m.realised_service_mean + g.looks * s.look_days) AS utilisation
FROM grid g, settings s, queue_moments m
ORDER BY g.looks, m.rnk;

-- Cobham on the labels, at each level of effort and under each tie-break.
--
-- A label's arrival rate and service moments are mixtures over the true classes feeding it, exactly as in
-- wave 6 - only now the services carry the triage time. A label nobody is sent to has no volume and drops
-- out, which is what makes zero looks collapse into first-come-first-served: with no information every tie
-- goes the same way and all three classes end up under one label.
CREATE OR REPLACE TABLE effort_labels AS
WITH flows AS (
    SELECT
        c.looks,
        c.tie_break,
        c.assigned_priority,
        c.assigned_rank,
        sum(c.probability * k.realised_rate)                          AS rate,
        sum(c.probability * k.realised_rate * k.service_mean)         AS utilisation,
        sum(c.probability * k.realised_rate * k.service_second_moment) AS rate_times_second_moment
    FROM effort_confusion c
    JOIN effort_capacity_by_class k ON k.looks = c.looks AND k.priority = c.true_priority
    GROUP BY 1, 2, 3, 4
),
accumulated AS (
    SELECT
        f.*,
        sum(f.utilisation) OVER (PARTITION BY f.looks, f.tie_break ORDER BY f.assigned_rank)
            AS through_this_rank,
        sum(f.utilisation) OVER (PARTITION BY f.looks, f.tie_break ORDER BY f.assigned_rank)
            - f.utilisation AS above_this_rank
    FROM flows f
)
SELECT
    a.looks,
    a.tie_break,
    a.assigned_priority,
    a.assigned_rank,
    a.rate,
    a.utilisation,
    a.rate_times_second_moment / a.rate                                       AS service_second_moment,
    a.above_this_rank,
    a.through_this_rank,
    e.residual_work / ((1.0 - a.above_this_rank) * (1.0 - a.through_this_rank)) AS derived_wait
FROM accumulated a
JOIN effort_capacity e ON e.looks = a.looks
ORDER BY a.looks, a.tie_break, a.assigned_rank;

-- And back onto the classes whose delay actually costs something.
CREATE OR REPLACE TABLE effort_classes AS
WITH composed AS (
    SELECT
        c.looks,
        c.tie_break,
        c.true_priority,
        c.true_rank,
        sum(c.probability)                    AS probability_total,
        sum(c.probability * l.derived_wait)   AS derived_wait
    FROM effort_confusion c
    JOIN effort_labels l
      ON l.looks = c.looks AND l.tie_break = c.tie_break
     AND l.assigned_priority = c.assigned_priority
    GROUP BY 1, 2, 3, 4
)
SELECT
    p.looks,
    p.tie_break,
    p.true_priority,
    p.true_rank,
    k.label,
    p.probability_total,
    p.derived_wait,
    -- The share of this class that the desk labels correctly, which is the accuracy the effort bought.
    (SELECT probability FROM effort_confusion c
      WHERE c.looks = p.looks AND c.tie_break = p.tie_break
        AND c.true_priority = p.true_priority AND c.assigned_priority = p.true_priority) AS correctly_labelled,
    m.realised_rate,
    u.urgency_weight
FROM composed p
JOIN queue_classes k ON k.priority = p.true_priority
JOIN queue_moments m ON m.priority = p.true_priority
JOIN queue_urgency u ON u.priority = p.true_priority
ORDER BY p.looks, p.tie_break, p.true_rank;

-- What the whole desk costs, at each level of effort, on the declared urgency scale.
--
-- Two ends to the trade. More looks buy accuracy, which moves waiting onto the classes that can afford it.
-- More looks also buy utilisation, which multiplies everybody's waiting by 1/(1 - rho). The optimum is
-- interior, and where it sits is the result.
CREATE OR REPLACE TABLE effort_cost AS
WITH totals AS (
    SELECT
        looks,
        tie_break,
        sum(urgency_weight * realised_rate * derived_wait) AS weighted_waiting,
        sum(realised_rate * derived_wait) / sum(realised_rate) AS mean_wait_per_demand,
        max(derived_wait) FILTER (WHERE true_rank = 1)     AS critical_wait,
        max(derived_wait) FILTER (WHERE true_rank = 3)     AS improvement_wait,
        max(correctly_labelled) FILTER (WHERE true_rank = 1) AS critical_accuracy,
        max(correctly_labelled) FILTER (WHERE true_rank = 3) AS improvement_accuracy
    FROM effort_classes
    GROUP BY 1, 2
)
SELECT
    t.looks,
    t.tie_break,
    e.utilisation,
    e.triage_days_per_demand,
    t.critical_accuracy,
    t.improvement_accuracy,
    t.critical_wait,
    t.improvement_wait,
    t.mean_wait_per_demand,
    t.weighted_waiting,
    -- Against spending nothing on triage, which is the same queue served first-come-first-served.
    t.weighted_waiting / (SELECT weighted_waiting FROM totals
                          WHERE looks = 0 AND tie_break = t.tie_break) AS against_no_triage,
    t.weighted_waiting = min(t.weighted_waiting) OVER (PARTITION BY t.tie_break) AS is_best_effort
FROM totals t
JOIN effort_capacity e ON e.looks = t.looks
ORDER BY t.tie_break, t.looks;
