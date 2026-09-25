-- The desk that decides how hard to look, demand by demand.
--
-- Wave 7 spends the same effort on every demand. This one spends it where it is needed: after each look the
-- posterior over the three classes is recomputed, and the desk commits as soon as the largest posterior
-- crosses the declared threshold. So the effort is no longer a parameter of the desk, it is an outcome of
-- the demands - and being an outcome, it has a mean *and a variance*, which is the second finding of the
-- wave.
--
-- One design note about the walk below, learned the expensive way. The rule "stop when the posterior
-- crosses the threshold" has to be evaluated exactly once per state and carried as a column. Writing it
-- twice - once as the condition for expanding a state and once as the condition for counting it - makes two
-- predicates out of one, and the probability then neither sums to one nor fails visibly. Carrying the flag
-- makes the partition structural instead of a coincidence of two identical expressions.
CREATE OR REPLACE MACRO posterior_weight(share, accuracy, votes, looks) AS
    share * pow(accuracy, votes) * pow((1.0 - accuracy) / 2.0, looks - votes);

-- The largest posterior after `looks` looks that fell (votes_p1, votes_p2, votes_p3).
CREATE OR REPLACE MACRO best_posterior(s1, s2, s3, accuracy, n1, n2, n3, looks) AS
    greatest(posterior_weight(s1, accuracy, n1, looks),
             posterior_weight(s2, accuracy, n2, looks),
             posterior_weight(s3, accuracy, n3, looks))
    / (posterior_weight(s1, accuracy, n1, looks)
     + posterior_weight(s2, accuracy, n2, looks)
     + posterior_weight(s3, accuracy, n3, looks));

-- Every path the desk can walk, and where each one stops.
--
-- The state is the true class and the three vote counts; the reach is the probability of arriving there. A
-- state is expanded only if it has not stopped, so the stopped states partition the probability exactly -
-- which tests/assert_stopping.sql checks rather than assumes.
CREATE OR REPLACE TABLE sequential_walk AS
WITH RECURSIVE
settings AS (
    SELECT
        (SELECT value FROM queue_effort WHERE key = 'look_accuracy')      AS accuracy,
        (SELECT value FROM queue_stopping WHERE key = 'look_budget')::INTEGER AS budget,
        (SELECT share FROM queue_classes WHERE rnk = 1)                   AS s1,
        (SELECT share FROM queue_classes WHERE rnk = 2)                   AS s2,
        (SELECT share FROM queue_classes WHERE rnk = 3)                   AS s3
),
walk AS (
    SELECT
        t.stop_threshold,
        c.rnk                         AS true_rank,
        0                             AS looks,
        0                             AS votes_p1,
        0                             AS votes_p2,
        0                             AS votes_p3,
        1.0::DOUBLE                   AS reach,
        (best_posterior(s.s1, s.s2, s.s3, s.accuracy, 0, 0, 0, 0) >= t.stop_threshold
            OR 0 >= s.budget)         AS stopped
    FROM queue_thresholds t, queue_classes c, settings s

    UNION ALL

    SELECT
        w.stop_threshold, w.true_rank, w.looks + 1, x.votes_p1, x.votes_p2, x.votes_p3, x.reach,
        (best_posterior(s.s1, s.s2, s.s3, s.accuracy, x.votes_p1, x.votes_p2, x.votes_p3, w.looks + 1)
            >= w.stop_threshold
         OR w.looks + 1 >= s.budget)
    FROM walk w, settings s, (VALUES (1), (2), (3)) AS v(reported),
         LATERAL (
            SELECT
                w.votes_p1 + (v.reported = 1)::INT AS votes_p1,
                w.votes_p2 + (v.reported = 2)::INT AS votes_p2,
                w.votes_p3 + (v.reported = 3)::INT AS votes_p3,
                w.reach * CASE WHEN v.reported = w.true_rank
                               THEN s.accuracy ELSE (1.0 - s.accuracy) / 2.0 END AS reach
         ) x
    WHERE NOT w.stopped
)
SELECT * FROM walk WHERE stopped;

-- What the desk commits to, and how many looks it took to get there.
--
-- Two labelling rules over the same walk, because the difference between them is the wave.
--
-- `accuracy` commits to the class with the largest posterior. That is the rule that maximises the chance of
-- putting the right label on the ticket, and it is what anybody asked to classify well would do.
--
-- `cost` commits to the class with the largest posterior *times its declared urgency*. That is the rule
-- that minimises expected cost under a loss proportional to urgency, and it is a different rule - because
-- the prior is 0.10 against the critical class, the accuracy rule is reluctant to call anything critical,
-- and wave 6 established that failing to recognise a critical demand costs 6.6 times what escalating a
-- routine one costs. An accuracy-maximising desk therefore commits the expensive error on purpose.
--
-- Both rules share the walk, the stopping and the effort, so the comparison isolates the objective.
CREATE OR REPLACE TABLE sequential_outcomes AS
WITH settings AS (
    SELECT
        (SELECT value FROM queue_effort WHERE key = 'look_accuracy') AS accuracy,
        (SELECT share FROM queue_classes WHERE rnk = 1) AS s1,
        (SELECT share FROM queue_classes WHERE rnk = 2) AS s2,
        (SELECT share FROM queue_classes WHERE rnk = 3) AS s3,
        (SELECT urgency_weight FROM queue_urgency u JOIN queue_classes c ON c.priority = u.priority WHERE c.rnk = 1) AS c1,
        (SELECT urgency_weight FROM queue_urgency u JOIN queue_classes c ON c.priority = u.priority WHERE c.rnk = 2) AS c2,
        (SELECT urgency_weight FROM queue_urgency u JOIN queue_classes c ON c.priority = u.priority WHERE c.rnk = 3) AS c3
),
weighted AS (
    SELECT
        w.*,
        posterior_weight(s.s1, s.accuracy, w.votes_p1, w.looks) AS weight_p1,
        posterior_weight(s.s2, s.accuracy, w.votes_p2, w.looks) AS weight_p2,
        posterior_weight(s.s3, s.accuracy, w.votes_p3, w.looks) AS weight_p3,
        s.c1, s.c2, s.c3
    FROM sequential_walk w, settings s
),
labelled AS (
    SELECT
        *,
        CASE WHEN weight_p1 >= weight_p2 AND weight_p1 >= weight_p3 THEN 1
             WHEN weight_p2 >= weight_p3 THEN 2 ELSE 3 END AS accuracy_rank,
        CASE WHEN weight_p1 * c1 >= weight_p2 * c2 AND weight_p1 * c1 >= weight_p3 * c3 THEN 1
             WHEN weight_p2 * c2 >= weight_p3 * c3 THEN 2 ELSE 3 END AS cost_rank,
        (weight_p1 = weight_p2 OR weight_p2 = weight_p3 OR weight_p1 = weight_p3) AS needed_a_tie_break
    FROM weighted
)
SELECT 'accuracy' AS rule, stop_threshold, true_rank, looks, reach, accuracy_rank AS assigned_rank,
       greatest(weight_p1, weight_p2, weight_p3) / (weight_p1 + weight_p2 + weight_p3) AS committed_posterior,
       needed_a_tie_break
FROM labelled
UNION ALL
SELECT 'cost', stop_threshold, true_rank, looks, reach, cost_rank,
       greatest(weight_p1, weight_p2, weight_p3) / (weight_p1 + weight_p2 + weight_p3),
       needed_a_tie_break
FROM labelled;

-- The confusion matrix the rule produces, and the effort it spends producing it.
CREATE OR REPLACE TABLE sequential_confusion AS
SELECT
    o.rule,
    o.stop_threshold,
    t.priority                AS true_priority,
    o.true_rank,
    a.priority                AS assigned_priority,
    o.assigned_rank,
    sum(o.reach)              AS probability
FROM sequential_outcomes o
JOIN queue_classes t ON t.rnk = o.true_rank
JOIN queue_classes a ON a.rnk = o.assigned_rank
GROUP BY 1, 2, 3, 4, 5, 6
HAVING sum(o.reach) > 0
ORDER BY o.rule, o.stop_threshold, o.true_rank, o.assigned_rank;

-- The effort, as a distribution rather than a number.
--
-- The mean is what a capacity plan would use. The second moment is what the queue actually charges, because
-- Pollaczek and Khinchine's residual work is built on E[S^2] and the triage time is part of S. A rule with
-- the same mean effort and more spread costs more waiting, and no triage policy measures the spread.
CREATE OR REPLACE TABLE sequential_looks AS
SELECT
    o.rule,
    o.stop_threshold,
    t.priority                                     AS priority,
    o.true_rank,
    sum(o.reach)                                   AS probability_mass,
    sum(o.reach * o.looks)                         AS mean_looks,
    sum(o.reach * o.looks * o.looks)               AS second_moment_looks,
    sum(o.reach * o.looks * o.looks) - pow(sum(o.reach * o.looks), 2) AS variance_looks,
    max(o.looks)                                   AS most_looks_taken,
    sum(o.reach) FILTER (WHERE o.assigned_rank = o.true_rank) AS correctly_labelled
FROM sequential_outcomes o
JOIN queue_classes t ON t.rnk = o.true_rank
GROUP BY 1, 2, 3, 4
ORDER BY o.rule, o.stop_threshold, o.true_rank;

-- What the effort costs the server, when the effort is random.
--
-- Wave 7's triage time was a constant, so it moved the mean service and the second moment in a way a single
-- addition covered. Here the number of looks is a random variable, independent of the handling time because
-- the two are drawn from different streams. For independent S and K,
--
--     E[(S + tau*K)^2] = E[S^2] + 2*tau*E[S]*E[K] + tau^2*E[K^2]
--
-- and the last term is the one that matters: the residual work charges the *second* moment of the triage
-- time, so a rule that looks a variable number of times is more expensive than a rule that looks E[K] times
-- on the nose. That difference is a cost of variation, and it is invisible to any plan built on averages.
CREATE OR REPLACE TABLE sequential_capacity_by_class AS
WITH settings AS (SELECT (SELECT value FROM queue_effort WHERE key = 'look_days') AS look_days)
SELECT
    l.rule,
    l.stop_threshold,
    l.priority,
    l.true_rank                                                     AS rnk,
    m.realised_rate,
    l.mean_looks,
    l.second_moment_looks,
    m.realised_service_mean + s.look_days * l.mean_looks            AS service_mean,
    m.realised_service_second_moment
        + 2.0 * s.look_days * m.realised_service_mean * l.mean_looks
        + pow(s.look_days, 2) * l.second_moment_looks               AS service_second_moment,
    m.realised_rate * (m.realised_service_mean + s.look_days * l.mean_looks) AS utilisation,
    -- The same queue if the desk looked exactly E[K] times instead of a variable number, which isolates
    -- what the spread costs on its own.
    m.realised_service_second_moment
        + 2.0 * s.look_days * m.realised_service_mean * l.mean_looks
        + pow(s.look_days * l.mean_looks, 2)                        AS second_moment_if_no_spread
FROM sequential_looks l, settings s
JOIN queue_moments m ON m.priority = l.priority
ORDER BY l.rule, l.stop_threshold, l.true_rank;

CREATE OR REPLACE TABLE sequential_capacity AS
SELECT
    rule,
    stop_threshold,
    sum(realised_rate * mean_looks) / sum(realised_rate)        AS mean_looks_per_demand,
    sum(utilisation)                                            AS utilisation,
    sum(realised_rate * service_second_moment) / 2.0            AS residual_work,
    sum(realised_rate * second_moment_if_no_spread) / 2.0       AS residual_work_if_no_spread,
    (sum(realised_rate * service_second_moment) / 2.0) / (1.0 - sum(utilisation))
                                                                AS wait_without_priority,
    (sum(realised_rate * second_moment_if_no_spread) / 2.0) / (1.0 - sum(utilisation))
                                                                AS wait_without_priority_no_spread
FROM sequential_capacity_by_class
GROUP BY rule, stop_threshold
ORDER BY rule, stop_threshold;

-- Cobham on the labels, then the composition onto the classes. Same machinery as waves 6 and 7.
CREATE OR REPLACE TABLE sequential_labels AS
WITH flows AS (
    SELECT
        c.rule,
        c.stop_threshold,
        c.assigned_priority,
        c.assigned_rank,
        sum(c.probability * k.realised_rate)                            AS rate,
        sum(c.probability * k.realised_rate * k.service_mean)           AS utilisation
    FROM sequential_confusion c
    JOIN sequential_capacity_by_class k
      ON k.rule = c.rule AND k.stop_threshold = c.stop_threshold AND k.priority = c.true_priority
    GROUP BY 1, 2, 3, 4
),
accumulated AS (
    SELECT
        f.*,
        sum(f.utilisation) OVER (PARTITION BY f.rule, f.stop_threshold ORDER BY f.assigned_rank)
            AS through_rank,
        sum(f.utilisation) OVER (PARTITION BY f.rule, f.stop_threshold ORDER BY f.assigned_rank)
            - f.utilisation AS above_rank
    FROM flows f
)
SELECT
    a.rule,
    a.stop_threshold,
    a.assigned_priority,
    a.assigned_rank,
    a.rate,
    a.utilisation,
    c.residual_work / ((1.0 - a.above_rank) * (1.0 - a.through_rank)) AS derived_wait
FROM accumulated a
JOIN sequential_capacity c ON c.rule = a.rule AND c.stop_threshold = a.stop_threshold
ORDER BY a.rule, a.stop_threshold, a.assigned_rank;

CREATE OR REPLACE TABLE sequential_classes AS
SELECT
    c.rule,
    c.stop_threshold,
    c.true_priority,
    c.true_rank,
    sum(c.probability)                  AS probability_total,
    sum(c.probability * l.derived_wait) AS derived_wait,
    m.realised_rate,
    u.urgency_weight
FROM sequential_confusion c
JOIN sequential_labels l
  ON l.rule = c.rule AND l.stop_threshold = c.stop_threshold
 AND l.assigned_priority = c.assigned_priority
JOIN queue_moments m ON m.priority = c.true_priority
JOIN queue_urgency u ON u.priority = c.true_priority
GROUP BY 1, 2, 3, 4, m.realised_rate, u.urgency_weight
ORDER BY c.rule, c.stop_threshold, c.true_rank;

-- What the sequential desk costs, against spending nothing and against wave 7's constant effort.
CREATE OR REPLACE TABLE sequential_cost AS
WITH totals AS (
    SELECT
        rule,
        stop_threshold,
        sum(urgency_weight * realised_rate * derived_wait)     AS weighted_waiting,
        sum(realised_rate * derived_wait) / sum(realised_rate) AS mean_wait_per_demand,
        max(derived_wait) FILTER (WHERE true_rank = 1)         AS critical_wait,
        max(derived_wait) FILTER (WHERE true_rank = 3)         AS improvement_wait
    FROM sequential_classes
    GROUP BY 1, 2
),
accuracy AS (
    SELECT
        l.rule,
        l.stop_threshold,
        sum(m.realised_rate * l.correctly_labelled) / sum(m.realised_rate) AS labels_correct,
        max(l.correctly_labelled) FILTER (WHERE l.true_rank = 1)           AS critical_correct
    FROM sequential_looks l JOIN queue_moments m ON m.priority = l.priority
    GROUP BY 1, 2
)
SELECT
    t.rule,
    t.stop_threshold,
    c.mean_looks_per_demand,
    c.utilisation,
    a.labels_correct,
    a.critical_correct,
    t.critical_wait,
    t.improvement_wait,
    t.mean_wait_per_demand,
    t.weighted_waiting,
    -- Against not triaging, which in this family is the lowest threshold.
    t.weighted_waiting / (SELECT weighted_waiting FROM totals
                          WHERE rule = t.rule
                            AND stop_threshold = (SELECT min(stop_threshold) FROM totals)) AS against_no_triage,
    -- And against wave 7's best constant effort, which is the honest comparison for the stopping rule.
    t.weighted_waiting / (SELECT min(weighted_waiting) FROM effort_cost WHERE tie_break = 'urgent')
                                                        AS against_best_constant_effort,
    t.weighted_waiting = min(t.weighted_waiting) OVER (PARTITION BY t.rule) AS is_best_threshold
FROM totals t
JOIN sequential_capacity c ON c.rule = t.rule AND c.stop_threshold = t.stop_threshold
JOIN accuracy a ON a.rule = t.rule AND a.stop_threshold = t.stop_threshold
ORDER BY t.rule, t.stop_threshold;
