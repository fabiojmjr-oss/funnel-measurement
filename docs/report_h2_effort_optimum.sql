-- The effort worth spending, against the utilisation the desk is already carrying. This is the prescription
-- of the wave: how carefully to classify is not a property of the desk, it is a property of how full it is.
SELECT
    base_utilisation                            AS utilisation_before_triage,
    tie_break,
    best_looks                                  AS looks_worth_spending,
    most_looks_feasible                         AS looks_even_possible,
    round(utilisation_with_triage, 4)           AS utilisation_at_that_effort,
    round(against_no_triage, 4)                 AS against_no_triage,
    triage_pays
FROM effort_optimum
ORDER BY tie_break, base_utilisation;
