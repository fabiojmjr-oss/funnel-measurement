-- What is actually in each label, and what the labelling costs each class.
SELECT
    assigned_label                              AS label,
    labelled                                    AS demands_carrying_it,
    round(share_of_all_demands, 4)              AS share_of_all_demands,
    round(share_correctly_labelled, 4)          AS share_that_belongs_there
FROM triage_purity
ORDER BY rnk;

SELECT
    label                                       AS demand_class,
    round(wait_under_perfect_triage, 4)         AS wait_if_triage_were_perfect,
    round(wait_under_real_triage, 4)            AS wait_under_this_triage_desk,
    round(wait_standard_error, 4)               AS clustered_standard_error,
    round(ratio, 4)                             AS ratio,
    round(wait_under_no_priority, 4)            AS wait_with_no_priority_at_all,
    round(sla_under_perfect_triage, 4)          AS target_met_if_perfect,
    round(sla_under_real_triage, 4)             AS target_met_in_practice
FROM triage_damage
ORDER BY rnk;
