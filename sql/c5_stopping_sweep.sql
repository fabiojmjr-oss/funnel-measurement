-- When sophistication pays, and when one look beats it.
--
-- At the declared utilisation the elaborate rule loses to wave 7's single fixed look, which is worth
-- reporting rather than hiding: the capacity a stopping rule spends deciding is charged at 1/(1 - rho), and
-- at 0.78 that charge dominates everything better labels can buy. The question the sweep answers is whether
-- that is a property of the rule or of the load - and it is the load.
--
-- One parameter moves: the arrival rate is scaled so the utilisation *before* any triage lands on each grid
-- value. The walk, the stopping rule, the accuracy of a look and the effort distribution are untouched,
-- because none of them depends on how fast demands arrive.
CREATE OR REPLACE TABLE stopping_sweep AS
WITH settings AS (
    SELECT
        (SELECT value FROM queue_effort WHERE key = 'look_days') AS look_days,
        (SELECT utilisation FROM effort_capacity WHERE looks = 0) AS base_utilisation
),
grid(base_utilisation) AS (
    VALUES (0.40), (0.50), (0.60), (0.65), (0.70), (0.75), (0.78), (0.82), (0.85), (0.86), (0.87),
           (0.88), (0.89), (0.90), (0.92), (0.95)
),
per_class AS (
    SELECT
        g.base_utilisation,
        l.rule,
        l.stop_threshold,
        l.priority,
        l.true_rank                                                  AS rnk,
        m.realised_rate * g.base_utilisation / s.base_utilisation    AS rate,
        m.realised_service_mean + s.look_days * l.mean_looks         AS service_mean,
        m.realised_service_second_moment
            + 2.0 * s.look_days * m.realised_service_mean * l.mean_looks
            + pow(s.look_days, 2) * l.second_moment_looks            AS service_second_moment
    FROM grid g, settings s, sequential_looks l
    JOIN queue_moments m ON m.priority = l.priority
),
capacity AS (
    SELECT
        base_utilisation, rule, stop_threshold,
        sum(rate * service_mean)                 AS utilisation,
        sum(rate * service_second_moment) / 2.0  AS residual_work
    FROM per_class GROUP BY 1, 2, 3
),
flows AS (
    SELECT
        p.base_utilisation, c.rule, c.stop_threshold, c.assigned_priority, c.assigned_rank,
        sum(c.probability * p.rate * p.service_mean) AS utilisation
    FROM sequential_confusion c
    JOIN per_class p
      ON p.base_utilisation IS NOT NULL AND p.rule = c.rule
     AND p.stop_threshold = c.stop_threshold AND p.priority = c.true_priority
    GROUP BY 1, 2, 3, 4, 5
),
accumulated AS (
    SELECT
        f.*,
        sum(f.utilisation) OVER (
            PARTITION BY f.base_utilisation, f.rule, f.stop_threshold ORDER BY f.assigned_rank) AS through_rank,
        sum(f.utilisation) OVER (
            PARTITION BY f.base_utilisation, f.rule, f.stop_threshold ORDER BY f.assigned_rank)
            - f.utilisation AS above_rank
    FROM flows f
),
label_waits AS (
    SELECT
        a.base_utilisation, a.rule, a.stop_threshold, a.assigned_priority,
        CASE WHEN c.utilisation >= 1.0 THEN NULL
             ELSE c.residual_work / ((1.0 - a.above_rank) * (1.0 - a.through_rank)) END AS derived_wait
    FROM accumulated a
    JOIN capacity c
      ON c.base_utilisation = a.base_utilisation AND c.rule = a.rule
     AND c.stop_threshold = a.stop_threshold
),
class_waits AS (
    SELECT
        w.base_utilisation, w.rule, w.stop_threshold, c.true_priority,
        sum(c.probability * w.derived_wait) AS derived_wait
    FROM sequential_confusion c
    JOIN label_waits w
      ON w.rule = c.rule AND w.stop_threshold = c.stop_threshold
     AND w.assigned_priority = c.assigned_priority
    GROUP BY 1, 2, 3, 4
),
totalled AS (
    SELECT
        cw.base_utilisation, cw.rule, cw.stop_threshold,
        sum(u.urgency_weight * p.rate * cw.derived_wait) AS weighted_waiting
    FROM class_waits cw
    JOIN per_class p
      ON p.base_utilisation = cw.base_utilisation AND p.rule = cw.rule
     AND p.stop_threshold = cw.stop_threshold AND p.priority = cw.true_priority
    JOIN queue_urgency u ON u.priority = cw.true_priority
    GROUP BY 1, 2, 3
)
SELECT
    t.base_utilisation,
    t.rule,
    t.stop_threshold,
    c.utilisation                AS utilisation_with_triage,
    c.utilisation >= 1.0         AS infeasible,
    t.weighted_waiting,
    t.weighted_waiting / (SELECT weighted_waiting FROM totalled
                          WHERE base_utilisation = t.base_utilisation AND rule = t.rule
                            AND stop_threshold = (SELECT min(stop_threshold) FROM queue_thresholds))
                                 AS against_no_triage
FROM totalled t
JOIN capacity c
  ON c.base_utilisation = t.base_utilisation AND c.rule = t.rule AND c.stop_threshold = t.stop_threshold
ORDER BY t.rule, t.base_utilisation, t.stop_threshold;

-- And the comparison the wave exists for: the best stopping rule against wave 7's best constant effort, at
-- each utilisation.
CREATE OR REPLACE TABLE stopping_versus_constant AS
WITH best_stopping AS (
    SELECT base_utilisation, rule, stop_threshold, weighted_waiting, against_no_triage
    FROM stopping_sweep
    WHERE NOT infeasible AND weighted_waiting IS NOT NULL
    QUALIFY weighted_waiting = min(weighted_waiting) OVER (PARTITION BY base_utilisation, rule)
),
best_constant AS (
    SELECT base_utilisation, best_looks, weighted_waiting, against_no_triage
    FROM effort_optimum WHERE tie_break = 'urgent'
)
SELECT
    s.base_utilisation,
    s.rule,
    s.stop_threshold                              AS best_threshold,
    s.weighted_waiting                            AS stopping_cost,
    c.best_looks                                  AS best_constant_looks,
    c.weighted_waiting                            AS constant_cost,
    s.weighted_waiting / c.weighted_waiting       AS stopping_over_constant,
    s.weighted_waiting < c.weighted_waiting       AS stopping_wins,
    s.against_no_triage                           AS stopping_against_no_triage,
    c.against_no_triage                           AS constant_against_no_triage
FROM best_stopping s
JOIN best_constant c ON c.base_utilisation = s.base_utilisation
ORDER BY s.rule, s.base_utilisation;
