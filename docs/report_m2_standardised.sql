-- The same subjects, the same conversions, the same definition of converted - and one different set of
-- weights. Holding the composition at the first half's shares turns the reported fall into a rise.
--
-- `demanda` is the clearest case in the table: standardised, it moved by less than a percentage point,
-- and as reported it lost more than eight. The whole movement was who arrived.
SELECT
    scope,
    round(rate_early, 4)                    AS rate_first_half,
    round(rate_late_as_reported, 4)         AS second_half_as_reported,
    round(rate_late_standardised, 4)        AS second_half_standardised,
    round(reported_change, 4)               AS reported_change,
    round(standardised_change, 4)           AS standardised_change,
    reported_change < 0 AND standardised_change > 0 AS sign_flips
FROM mix_standardised
ORDER BY scope_position, scope;
