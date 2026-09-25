-- The artefact a review actually receives: six changes ranked by measured lift, at each horizon the reading
-- might have been taken at. The rank on the left is the one in the meeting; the rank on the right is the one
-- the changes deserve.
--
-- At twenty days the two changes that converted nobody rank first and second, and the change that converted
-- the most people ranks below both of them. At thirty the page looks respectable and is still wrong: the two
-- real lifts are in the wrong order, and a change worth nothing is credited with a fifth more conversion.
SELECT
    maturity                        AS horizon_days,
    rank_as_measured,
    funnel,
    kind,
    round(measured_lift, 4)         AS measured_lift,
    round(declared_lift, 4)         AS true_lift,
    rank_as_declared,
    credited_with_nothing,
    understated,
    measured_lift < best_worthless_lift AS outranked_by_a_worthless_change
FROM lift_ranking
ORDER BY maturity, rank_as_measured;
