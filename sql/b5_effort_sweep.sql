-- The effort that pays, against the utilisation the desk is already carrying.
--
-- The trade of sql/b0_effort.sql has one end that grows with accuracy and one that grows with utilisation,
-- and the second end is not linear: it carries 1/(1 - rho). So the answer to "how carefully should this desk
-- classify" cannot be a property of the desk. It has to be a property of how full the desk already is.
--
-- The sweep moves one parameter. The arrival rate is scaled so that the utilisation *before* any triage
-- lands on each declared grid value; service times, class shares and the accuracy of a look are untouched.
-- Points whose utilisation reaches one once the triage time is added are infeasible rather than expensive,
-- and are reported as such instead of being given a number.
CREATE OR REPLACE TABLE effort_sweep AS
WITH settings AS (
    SELECT
        (SELECT value FROM queue_effort WHERE key = 'look_days') AS look_days,
        (SELECT utilisation FROM effort_capacity WHERE looks = 0) AS base_utilisation
),
grid(base_utilisation) AS (
    VALUES (0.40), (0.50), (0.60), (0.65), (0.70), (0.75), (0.78), (0.82), (0.85), (0.86), (0.87),
           (0.88), (0.89), (0.90), (0.92), (0.95)
),
looks_grid(looks) AS (VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8)),
-- Per true class, at each swept utilisation and each effort.
per_class AS (
    SELECT
        g.base_utilisation,
        l.looks,
        m.priority,
        m.rnk,
        m.realised_rate * g.base_utilisation / s.base_utilisation           AS rate,
        m.realised_service_mean + l.looks * s.look_days                     AS service_mean,
        m.realised_service_second_moment
            + 2.0 * l.looks * s.look_days * m.realised_service_mean
            + pow(l.looks * s.look_days, 2)                                 AS service_second_moment
    FROM grid g, looks_grid l, settings s, queue_moments m
),
capacity AS (
    SELECT
        base_utilisation,
        looks,
        sum(rate * service_mean)                        AS utilisation,
        sum(rate * service_second_moment) / 2.0         AS residual_work
    FROM per_class
    GROUP BY 1, 2
),
-- Labels, exactly as in sql/b0_effort.sql but at the swept rates.
flows AS (
    SELECT
        p.base_utilisation,
        c.looks,
        c.tie_break,
        c.assigned_priority,
        c.assigned_rank,
        sum(c.probability * p.rate)                     AS rate,
        sum(c.probability * p.rate * p.service_mean)    AS utilisation
    FROM effort_confusion c
    JOIN per_class p ON p.looks = c.looks AND p.priority = c.true_priority
    GROUP BY 1, 2, 3, 4, 5
),
accumulated AS (
    SELECT
        f.*,
        sum(f.utilisation) OVER (
            PARTITION BY f.base_utilisation, f.looks, f.tie_break ORDER BY f.assigned_rank) AS through_rank,
        sum(f.utilisation) OVER (
            PARTITION BY f.base_utilisation, f.looks, f.tie_break ORDER BY f.assigned_rank)
            - f.utilisation AS above_rank
    FROM flows f
),
label_waits AS (
    SELECT
        a.base_utilisation, a.looks, a.tie_break, a.assigned_priority,
        CASE WHEN c.utilisation >= 1.0 THEN NULL
             ELSE c.residual_work / ((1.0 - a.above_rank) * (1.0 - a.through_rank)) END AS derived_wait
    FROM accumulated a
    JOIN capacity c ON c.base_utilisation = a.base_utilisation AND c.looks = a.looks
),
class_waits AS (
    SELECT
        w.base_utilisation, w.looks, w.tie_break, c.true_priority,
        sum(c.probability * w.derived_wait) AS derived_wait
    FROM effort_confusion c
    JOIN label_waits w
      ON w.looks = c.looks AND w.tie_break = c.tie_break
     AND w.assigned_priority = c.assigned_priority
    GROUP BY 1, 2, 3, 4
),
totalled AS (
    SELECT
        cw.base_utilisation,
        cw.looks,
        cw.tie_break,
        sum(u.urgency_weight * p.rate * cw.derived_wait) AS weighted_waiting
    FROM class_waits cw
    JOIN per_class p
      ON p.base_utilisation = cw.base_utilisation AND p.looks = cw.looks AND p.priority = cw.true_priority
    JOIN queue_urgency u ON u.priority = cw.true_priority
    GROUP BY 1, 2, 3
)
SELECT
    t.base_utilisation,
    t.looks,
    t.tie_break,
    c.utilisation                                        AS utilisation_with_triage,
    c.utilisation >= 1.0                                 AS infeasible,
    t.weighted_waiting,
    t.weighted_waiting / (SELECT weighted_waiting FROM totalled
                          WHERE base_utilisation = t.base_utilisation
                            AND tie_break = t.tie_break AND looks = 0)   AS against_no_triage
FROM totalled t
JOIN capacity c ON c.base_utilisation = t.base_utilisation AND c.looks = t.looks
ORDER BY t.tie_break, t.base_utilisation, t.looks;

-- The effort worth spending, per utilisation. This is the table the wave is for.
CREATE OR REPLACE TABLE effort_optimum AS
WITH feasible AS (SELECT * FROM effort_sweep WHERE NOT infeasible AND weighted_waiting IS NOT NULL)
SELECT
    base_utilisation,
    tie_break,
    looks                                          AS best_looks,
    utilisation_with_triage,
    weighted_waiting,
    against_no_triage,
    (SELECT max(looks) FROM feasible f
      WHERE f.base_utilisation = feasible.base_utilisation AND f.tie_break = feasible.tie_break)
                                                   AS most_looks_feasible,
    against_no_triage < 1.0                        AS triage_pays
FROM feasible
QUALIFY weighted_waiting = min(weighted_waiting) OVER (PARTITION BY base_utilisation, tie_break)
ORDER BY tie_break, base_utilisation;
