-- The queue, derived on paper.
--
-- Every figure in sql/90_queue.sql is a simulation, and a simulation checked against itself has been
-- checked against nothing. M/G/1 with non-preemptive priority is chosen precisely because its mean
-- waiting time is known in closed form for every class under every priority order, so the arithmetic
-- here is done separately and the two are compared.
--
-- Three results are needed, and all three come from the same quantity - the mean residual work a new
-- arrival finds in the server and the queue ahead of it:
--
--     W0 = sum over classes of lambda_k * E[S_k^2] / 2
--
--   * first-come-first-served (Pollaczek and Khinchine):   W = W0 / (1 - rho)
--   * non-preemptive priority (Cobham):  W_k = W0 / ((1 - sigma_{r-1}) * (1 - sigma_r))
--     where r is the class's rank and sigma_r is the utilisation contributed by ranks 1 to r
--   * and the conservation law, which is the wave:
--         sum over classes of rho_k * W_k  =  rho * W0 / (1 - rho)
--     the same value for every non-preemptive work-conserving discipline, including the two above.
--
-- The comparison is made at the **realised** moments of the generated stream rather than at the declared
-- ones, and that is a deliberate choice worth defending. The waiting time carries a factor 1/(1 - rho),
-- so at the declared 0.78 a sampling error of one percent in rho moves the closed form by three and a
-- half percent. Comparing the simulation to the formula evaluated at declared parameters would test the
-- simulation and the draw at the same time and fail to say which one moved. So the draw is checked
-- against the declared parameters on its own, in `queue_moments`, and the simulation is checked against
-- the formula fed the draw's own moments. The violence of that factor is not a nuisance here; it is
-- result 4.
CREATE OR REPLACE TABLE queue_moments AS
WITH horizon AS (SELECT max(arrival) AS elapsed, count(*) AS demands FROM queue_demands),
per_class AS (
    SELECT
        priority,
        count(*)                                  AS demands,
        count(*) / (SELECT demands FROM horizon)::DOUBLE AS realised_share,
        count(*) / (SELECT elapsed FROM horizon)  AS realised_rate,
        avg(service)                              AS realised_service_mean,
        avg(service * service)                    AS realised_service_second_moment,
        sum(service) / (SELECT elapsed FROM horizon) AS realised_utilisation
    FROM queue_demands
    GROUP BY 1
)
SELECT
    c.priority,
    c.rnk,
    c.label,
    c.share                                       AS declared_share,
    p.realised_share,
    c.service_mean_days                           AS declared_service_mean,
    p.realised_service_mean,
    -- An exponential has E[S^2] = 2 * E[S]^2, which is the only property of the service distribution the
    -- formulas above need and therefore the only one worth declaring.
    2.0 * c.service_mean_days * c.service_mean_days AS declared_service_second_moment,
    p.realised_service_second_moment,
    c.share * (SELECT value FROM queue_params WHERE key = 'queue_arrivals_daily')
        * c.service_mean_days                     AS declared_utilisation,
    p.realised_utilisation,
    p.realised_rate,
    p.demands,
    -- Four standard errors of each mean, for the assertions that compare the two.
    4.0 * sqrt(c.share * (1 - c.share) / (SELECT demands FROM horizon)) AS share_tolerance,
    4.0 * c.service_mean_days / sqrt(p.demands)                        AS service_mean_tolerance
FROM queue_classes c
JOIN per_class p ON p.priority = c.priority
ORDER BY c.rnk;

-- The residual work, and the utilisation accumulated down each priority order.
CREATE OR REPLACE TABLE queue_residual AS
SELECT
    sum(realised_rate * realised_service_second_moment) / 2.0 AS residual_work,
    sum(realised_utilisation)                                 AS utilisation
FROM queue_moments;

CREATE OR REPLACE TABLE queue_closed_form AS
WITH ranked AS (
    SELECT
        d.discipline,
        d.priority,
        d.rnk,
        m.realised_utilisation,
        sum(m.realised_utilisation) OVER (PARTITION BY d.discipline ORDER BY d.rnk)
            AS through_this_rank,
        sum(m.realised_utilisation) OVER (PARTITION BY d.discipline ORDER BY d.rnk)
            - m.realised_utilisation AS above_this_rank
    FROM queue_disciplines d
    JOIN queue_moments m ON m.priority = d.priority
),
priority_forms AS (
    SELECT
        discipline,
        priority,
        rnk                                                            AS discipline_rank,
        realised_utilisation,
        r.residual_work / ((1.0 - above_this_rank) * (1.0 - through_this_rank)) AS derived_wait
    FROM ranked, queue_residual r
),
fifo_form AS (
    SELECT
        'fifo'                                        AS discipline,
        m.priority,
        NULL::INTEGER                                 AS discipline_rank,
        m.realised_utilisation,
        r.residual_work / (1.0 - r.utilisation)       AS derived_wait
    FROM queue_moments m, queue_residual r
),
derived AS (SELECT * FROM priority_forms UNION ALL SELECT * FROM fifo_form)
SELECT
    d.discipline,
    d.priority,
    c.label,
    d.discipline_rank,
    d.realised_utilisation,
    d.derived_wait,
    q.mean_wait                                        AS simulated_wait,
    q.wait_standard_error,
    (q.mean_wait - d.derived_wait) / q.wait_standard_error AS deviation_standard_errors
FROM derived d
JOIN queue_readings q ON q.discipline = d.discipline AND q.priority = d.priority
JOIN queue_classes c ON c.priority = d.priority
ORDER BY d.discipline, c.rnk;

-- The conservation law, twice: once as arithmetic, once as the simulation.
--
-- The two are not the same statement. The closed-form column is a steady-state identity about the
-- declared process. The simulated column is an exact identity about this particular realisation, and it
-- holds because the area under the unfinished-work curve does not depend on the order the queue is
-- served in. The second is the stronger claim, which is why it is asserted at machine precision and the
-- first at four standard errors.
CREATE OR REPLACE TABLE queue_conservation AS
WITH closed AS (
    SELECT
        discipline,
        sum(realised_utilisation * derived_wait) AS derived_work_weighted_rate
    FROM queue_closed_form
    WHERE discipline <> 'fifo'
    GROUP BY 1
    UNION ALL
    SELECT 'fifo', (SELECT utilisation * residual_work / (1.0 - utilisation) FROM queue_residual)
),
simulated AS (
    SELECT
        discipline,
        work_weighted_wait / (SELECT max(arrival) FROM queue_demands) AS simulated_work_weighted_rate,
        work_weighted_standard_error,
        mean_wait_per_day_of_work,
        mean_wait_per_demand
    FROM queue_totals
)
SELECT
    s.discipline,
    c.derived_work_weighted_rate,
    s.simulated_work_weighted_rate,
    s.mean_wait_per_day_of_work,
    s.mean_wait_per_demand,
    -- What the choice of discipline does to each of the two totals, against first-come-first-served.
    s.work_weighted_standard_error,
    (s.simulated_work_weighted_rate - c.derived_work_weighted_rate)
        / (s.work_weighted_standard_error * (SELECT utilisation FROM queue_residual))
                                                                                     AS deviation_standard_errors,
    s.mean_wait_per_day_of_work
        / (SELECT mean_wait_per_day_of_work FROM queue_totals WHERE discipline = 'fifo') AS invariant_ratio,
    s.mean_wait_per_demand
        / (SELECT mean_wait_per_demand FROM queue_totals WHERE discipline = 'fifo')      AS reported_ratio
FROM simulated s
JOIN closed c ON c.discipline = s.discipline
ORDER BY s.discipline;

-- The swept utilisations against the same formula, which is where the convexity is.
CREATE OR REPLACE TABLE queue_sweep_closed_form AS
WITH moments AS (
    -- The sweep runs on a prefix of the stream, so it has its own moments.
    SELECT
        avg(service * service) AS second_moment,
        avg(service)           AS service_mean
    FROM queue_demands
    WHERE job_id <= (SELECT value FROM queue_params WHERE key = 'queue_sweep_jobs')::BIGINT
),
points AS (
    SELECT
        s.utilisation,
        s.discipline,
        s.demands,
        s.mean_wait_per_demand,
        s.mean_wait_per_day_of_work,
        -- At utilisation u the arrival rate is u / E[S], which is what the scaling of the arrival
        -- instants was chosen to produce.
        (s.utilisation / m.service_mean) * m.second_moment / 2.0 / (1.0 - s.utilisation) AS derived_wait
    FROM queue_sweep s, moments m
)
SELECT
    utilisation,
    discipline,
    demands,
    mean_wait_per_demand,
    mean_wait_per_day_of_work,
    derived_wait,
    mean_wait_per_day_of_work / derived_wait AS ratio_to_derivation,
    -- What one more percent of demand costs, at this utilisation. The elasticity of W0/(1-u) in u is
    -- 1/(1-u), so the same extra demand is worth five times more at 0.90 than at 0.50.
    1.0 / (1.0 - utilisation)                AS elasticity_of_waiting_in_demand
FROM points
ORDER BY utilisation, discipline;

-- And what a 180-day slice of the same queue could have been mistaken for.
--
-- The slice means of `queue_measurability` are read back against the dense utilisation sweep: for the
-- lowest and the highest slice, the utilisation whose derived mean wait is closest to what that slice
-- reported. Both are the same desk at the same utilisation.
CREATE OR REPLACE TABLE queue_mistaken_for AS
WITH readings AS (
    SELECT 'lowest slice' AS slice, lowest_slice_mean AS reported FROM queue_measurability
    UNION ALL SELECT 'highest slice', highest_slice_mean FROM queue_measurability
    UNION ALL SELECT 'true value', mean_of_slice_means FROM queue_measurability
),
candidates AS (
    SELECT r.slice, r.reported, f.utilisation, f.derived_wait,
           abs(f.derived_wait - r.reported) AS distance
    FROM readings r, queue_sweep_closed_form f
    WHERE f.discipline = 'fifo'
)
SELECT slice, reported, utilisation AS looks_like_utilisation, derived_wait
FROM candidates
QUALIFY distance = min(distance) OVER (PARTITION BY slice)
ORDER BY reported;
