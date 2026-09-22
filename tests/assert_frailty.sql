-- The mixture, and the one thing about it that has to be exact.
--
-- The two classes are calibrated to leave the **true** mean delay where the single exponential had it,
-- so nothing about the average speed of the funnel changes and every comparison below is about spread
-- alone. That calibration is an identity and is asserted as one.
--
-- The **observed** mean is a different matter and is deliberately not asserted to be unchanged: it falls,
-- because extra spread puts more of the slow class beyond the horizon where nobody can see it. That is
-- wave 2's finding arriving again through a door wave 2 did not have, and it is published rather than
-- asserted away.
SELECT 'the class shares do not sum to one' AS failure, 'shares' AS detail, round(sum(share), 9) AS value
FROM frailty HAVING abs(sum(share) - 1.0) > 1e-9

UNION ALL
SELECT 'the mixture does not preserve the mean delay', 'mean multiplier',
       round(sum(share * multiplier), 9)
FROM frailty HAVING abs(sum(share * multiplier) - 1.0) > 1e-6

UNION ALL
SELECT 'the slow class is not slower than the fast one', 'multipliers', 0
WHERE (SELECT multiplier FROM frailty WHERE class = 'slow')
   <= (SELECT multiplier FROM frailty WHERE class = 'fast')

UNION ALL
-- The class draw is one coin on a salt nothing else uses, so its realised share has to sit on the
-- declared one. Four standard errors of a binomial on the whole population.
SELECT 'the realised share of the slow class is off the declared one', 'slow',
       round((observed - declared) / sqrt(declared * (1 - declared) / n), 3)
FROM (
    SELECT
        (SELECT count(*) FILTER (WHERE class = 'slow') / count(*)::DOUBLE FROM subject_class) AS observed,
        (SELECT share FROM frailty WHERE class = 'slow')                                      AS declared,
        (SELECT count(*) FROM subject_class)                                                  AS n
)
WHERE abs((observed - declared) / sqrt(declared * (1 - declared) / n)) > 4.0

UNION ALL
-- And the estimator is still right on the mixture, because the classes are a property of the subjects
-- rather than of the observation. Checked against the two-exponential closed form.
SELECT 'the estimator is off the mixture closed form by more than four standard errors', j.funnel,
       round((j.incidence - j.incidence_closed) / j.se, 3)
FROM (
    SELECT
        c.funnel,
        k.incidence,
        c.incidence_closed,
        sqrt(c.incidence_closed * (1 - c.incidence_closed)
             / (SELECT count(*) FROM subjects s WHERE s.funnel = c.funnel)) AS se
    FROM frailty_closed_form c
    JOIN (
        SELECT funnel, step, incidence FROM frail_survival
        WHERE time <= (SELECT value FROM params WHERE key = 'maturity_days')
        QUALIFY time = max(time) OVER (PARTITION BY funnel, step)
    ) k ON k.funnel = c.funnel AND k.step = 2
) j
WHERE abs((j.incidence - j.incidence_closed) / j.se) > 4.0;
