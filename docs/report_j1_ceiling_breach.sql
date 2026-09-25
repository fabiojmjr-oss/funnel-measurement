-- Wave 1's cheapest diagnostic was that a stage reading above the product of its pass rates proves the
-- reading is not a rate. This is what a skip does to it.
--
-- A first entry reaches step three either by passing step two and then step three or by skipping step two
-- and then passing step three, so the reach is [(1-s)*p2 + s]*p3 against a ceiling of p2*p3 - above it by
-- 1 + s*(1-p2)/p2, on a generator that obeys every declared rate exactly. Tolerance is four standard
-- errors of the simulated share, not a fixed epsilon.
SELECT
    funnel,
    round(skip_rate, 2)                 AS skip_rate,
    round(pass_two, 2)                  AS pass_two,
    round(pass_three, 2)                AS pass_three,
    round(declared_ceiling, 4)          AS declared_ceiling,
    round(derived_reach, 4)             AS derived_reach,
    round(simulated_reach, 4)           AS first_entry_reach,
    round(abs(derived_reach - simulated_reach), 4) AS gap,
    round(tolerance, 4)                 AS tolerance,
    round(derived_over_ceiling, 4)      AS derived_over_ceiling
FROM movement_closed_form
ORDER BY position;

-- And why the diagnostic cannot be used either way. The windowed cohort reading - the reading every other
-- wave here takes - moves the same figure in the opposite direction, because the maturity window censors
-- the slow walks the skip is adding. Venda reads seventeen percent above its ceiling with nothing wrong.
-- Retencao is being bypassed at the same rate and reads *below* its ceiling, because its stage delays are
-- long enough for the window to hide the breach. One diagnostic, both error directions.
SELECT
    funnel,
    round(declared_ceiling, 4)          AS declared_ceiling,
    round(simulated_reach, 4)           AS first_entry_reach,
    round(windowed_reach, 4)            AS windowed_reach,
    round(window_reentry_gap, 4)        AS windowed_minus_first_entry,
    round(windowed_reach / declared_ceiling, 4) AS windowed_over_ceiling,
    windowed_reach < declared_ceiling   AS window_masks_the_breach
FROM movement_closed_form
ORDER BY position;
