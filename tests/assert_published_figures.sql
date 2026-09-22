-- Every figure quoted in a README, re-derived.
--
-- The discipline carried from the sibling repositories: a number in prose is a number nobody compiles,
-- so each one is listed here against what the models produce. A change that moves a published figure
-- breaks the build instead of leaving the text quietly wrong.
WITH expected(what, detail, value) AS (
    VALUES
    -- The account itself.
    ('subjects',                'all',         47317.0),
    ('events',                  'all',        144858.0),
    ('events observed',         'all',        137923.0),
    ('funnels',                 'all',             6.0),

    -- The six funnels at their last stage, ordered by arrival growth in the README.
    ('window_rate',   'resgate reativado',        0.0743),
    ('cohort_rate',   'resgate reativado',        0.0375),
    ('declared_rate', 'resgate reativado',        0.0602),
    ('ratio',         'resgate reativado',        1.9826),
    ('window_rate',   'retencao renovado',        0.1080),
    ('cohort_rate',   'retencao renovado',        0.0636),
    ('ratio',         'retencao renovado',        1.6988),
    ('window_rate',   'atendimento confirmado',   0.4537),
    ('cohort_rate',   'atendimento confirmado',   0.4764),
    ('ratio',         'atendimento confirmado',   0.9522),
    ('ratio',         'ativacao uso-recorrente',  0.9907),
    ('window_rate',   'venda fechado',            0.0541),
    ('cohort_rate',   'venda fechado',            0.0587),
    ('declared_rate', 'venda fechado',            0.0737),
    ('ratio',         'venda fechado',            0.9218),
    ('window_rate',   'demanda entregue',         0.2198),
    ('cohort_rate',   'demanda entregue',         0.2308),
    ('declared_rate', 'demanda entregue',         0.3529),
    ('ratio',         'demanda entregue',         0.9524),

    -- The sales funnel shown stage by stage.
    ('window_rate',   'venda qualificado',        0.4267),
    ('cohort_rate',   'venda qualificado',        0.4464),
    ('window_rate',   'venda proposta',           0.2149),
    ('cohort_rate',   'venda proposta',           0.2374),
    ('window_rate',   'venda negociacao',         0.1243),
    ('cohort_rate',   'venda negociacao',         0.1389),

    -- The ceiling breaches: a reading above the rate it cannot exceed.
    ('breaches',                'all',             6.0),
    ('worst breach',            'resgate respondeu', 1.4161),

    -- Mechanism one: growth, with the delay held fixed.
    ('sweep window at -3%',     'growth',          0.4871),
    ('sweep window at 0%',      'growth',          0.4500),
    ('sweep window at +3%',     'growth',          0.4181),
    ('sweep ratio at -3%',      'growth',          1.0825),
    ('sweep ratio at +3%',      'growth',          0.9292),

    -- Mechanism two: the delay, with arrivals held flat.
    ('sweep cohort at m=1',     'lag',             0.4500),
    ('sweep cohort at m=30',    'lag',             0.2845),
    ('sweep cohort at m=60',    'lag',             0.1771),
    ('sweep ratio at m=30',     'lag',             1.5754),
    ('sweep ratio at m=60',     'lag',             2.3787),
    ('worst truncation gap',    'lag',             0.0019),

    -- Two claims the prose makes about the whole sweep and the whole verification.
    ('largest deviation from the derivation', 'standard errors', 2.0400),
    ('dashboard at -3% over dashboard at +3%', 'spread',         1.1651),
    ('points in the growth sweep',            'count',          61.0000),

    -- Wave 2: the time dimension.
    ('declared_mean',    'retencao renovado',           30.0000),
    ('naive_mean',       'retencao renovado',           26.8200),
    ('restricted_mean',  'retencao renovado',           29.1500),
    ('naive_over_declared', 'retencao renovado',         0.8940),
    ('declared_mean',    'resgate reativado',           29.0000),
    ('naive_mean',       'resgate reativado',           29.0700),
    ('restricted_mean',  'resgate reativado',           29.6400),
    ('naive_over_declared', 'resgate reativado',         1.0020),
    ('naive_mean',       'demanda entregue',            22.0900),
    ('naive_over_declared', 'demanda entregue',          0.8180),
    ('naive_mean',       'venda fechado',               20.0800),
    ('restricted_mean',  'venda fechado',               29.2400),
    ('naive_mean',       'ativacao uso-recorrente',     17.5500),
    ('naive_mean',       'atendimento confirmado',       5.0100),
    ('restricted_mean',  'atendimento confirmado',      18.1300),
    ('velocity sweep reads at -3%', 'growth',           19.7140),
    ('velocity sweep reads at 0%',  'growth',           17.5110),
    ('velocity sweep reads at +3%', 'growth',           12.5140),
    ('velocity ratio at -3%',       'growth',            0.9857),
    ('velocity ratio at 0%',        'growth',            0.8756),
    ('velocity ratio at +3%',       'growth',            0.6257),
    ('true speed factor',    'retencao over atendimento', 5.7700),
    ('restricted factor',    'retencao over atendimento', 1.6100),
    ('largest velocity deviation', 'standard errors',     1.1100),
    ('funnel that is slowest reads slowest', 'inversion',  0.0000),

    -- Wave 3: the product-limit estimator.
    ('subjects too young for cohorts', 'count',           14093.0000),
    ('share discarded by cohorts',     'share',               0.2980),
    ('km_incidence', 'venda qualificado',                      0.4453),
    ('km_incidence', 'ativacao configurado',                   0.7833),
    ('km_incidence', 'retencao em-risco',                      0.1661),
    ('km_incidence', 'resgate elegivel',                       0.5820),
    ('km_incidence', 'atendimento triado',                     0.9582),
    ('km_incidence', 'demanda classificada',                   0.9408),
    ('km_standard_error',     'venda qualificado',             0.0058),
    ('cohort_standard_error', 'venda qualificado',             0.0070),
    ('standard_error_ratio',  'venda qualificado',             0.8302),
    ('standard_error_ratio',  'demanda classificada',          0.7698),
    ('standard_error_ratio',  'retencao em-risco',             0.9506),
    ('standard_error_ratio',  'resgate elegivel',              0.9756),
    ('standard_error_ratio',  'atendimento triado',            0.8953),
    ('best error ratio',      'all stages',                    0.7698),
    ('worst error ratio',     'all stages',                    0.9809),
    ('mean equivalent sample','all stages',                    1.2400),
    ('demanda equivalent sample', 'classificada',              1.6880),
    ('largest survival deviation', 'standard errors',          1.0500),
    ('worst half-life gap',   'relative',                      0.0282),
    ('stages with no median', 'count',                        14.0000),
    ('stages beyond entry',   'count',                        22.0000),
    ('plateau_incidence', 'resgate abordado',                  0.4992),
    ('plateau_incidence', 'venda fechado',                     0.0723),
    ('plateau_incidence', 'retencao renovado',                 0.1047),
    ('plateau_incidence', 'demanda priorizada',                0.6817),
    ('plateau_incidence', 'atendimento triado',                0.9582),
    ('half_life_days', 'venda fechado',                       19.9110),
    ('half_life_days', 'retencao renovado',                   24.2310),
    ('half_life_days', 'resgate abordado',                    13.2570),
    ('half_life_days', 'atendimento triado',                   0.1390),
    ('half_life_days', 'demanda priorizada',                   3.1830),

    -- Wave 4: the mixture, and the review that censors by judgement.
    ('mixture mean multiplier', 'exact',                       1.0000),
    ('slow class multiplier',   'declared',                    2.5000),
    ('fast class multiplier',   'declared',                    0.3571),
    ('realised slow share',     'observed',                    0.2987),
    ('largest mixture deviation', 'standard errors',            1.3800),
    ('observed mean, one exponential', 'retencao',            17.2008),
    ('observed mean, two classes',     'retencao',            14.5152),
    ('observed mean ratio',            'retencao',              0.8439),
    ('observed mean ratio',            'resgate',               0.9019),
    ('observed mean ratio',            'venda',                 0.9459),
    ('observed mean ratio',            'atendimento',           1.0047),
    ('records archived',        'at 21 days',               9541.0000),
    ('share of archived that are slow', 'at 21 days',           0.7555),
    ('review selectivity',      'slow over population',         2.5290),
    ('sweep ratio', 'retencao at 3 days',                       1.0450),
    ('sweep ratio', 'retencao at 7 days',                       1.0276),
    ('sweep ratio', 'retencao at 14 days',                      1.0036),
    ('sweep ratio', 'retencao at 21 days',                      1.0082),
    ('sweep ratio', 'venda at 3 days',                          0.9372),
    ('sweep ratio', 'venda at 7 days',                          0.9700),
    ('sweep ratio', 'venda at 21 days',                         0.9986),
    ('sweep points at or beyond the horizon', 'count',         18.0000),
    ('unbiased at or beyond the horizon',     'count',         18.0000),
    ('sweep points inside the horizon',       'count',         36.0000),
    ('unbiased inside the horizon',           'count',          6.0000),
    ('sweep points above one inside',         'count',          7.0000),
    ('sweep points below one inside',         'count',         23.0000)
),
measured(what, detail, value) AS (
    SELECT 'subjects', 'all', count(*)::DOUBLE FROM subjects
    UNION ALL SELECT 'events', 'all', count(*)::DOUBLE FROM events
    UNION ALL SELECT 'events observed', 'all', count(*)::DOUBLE FROM events WHERE observed
    UNION ALL SELECT 'funnels', 'all', count(*)::DOUBLE FROM funnels

    UNION ALL SELECT 'window_rate', funnel || ' ' || stage, round(window_rate, 4) FROM distortion
    UNION ALL SELECT 'cohort_rate', funnel || ' ' || stage, round(cohort_rate, 4) FROM distortion
    UNION ALL SELECT 'declared_rate', funnel || ' ' || stage, round(declared_rate, 4) FROM distortion
    UNION ALL SELECT 'ratio', funnel || ' ' || stage, round(ratio, 4) FROM distortion

    UNION ALL SELECT 'window_rate', funnel || ' ' || stage, round(window_rate, 4)
        FROM readings WHERE funnel = 'venda' AND step BETWEEN 2 AND 4
    UNION ALL SELECT 'cohort_rate', funnel || ' ' || stage, round(cohort_rate, 4)
        FROM readings WHERE funnel = 'venda' AND step BETWEEN 2 AND 4

    UNION ALL SELECT 'breaches', 'all', count(*)::DOUBLE
        FROM readings WHERE step > 1 AND window_rate > declared_rate
    UNION ALL SELECT 'worst breach', 'resgate respondeu', round(max(window_rate / declared_rate), 4)
        FROM readings WHERE step > 1 AND window_rate > declared_rate

    UNION ALL SELECT 'sweep window at -3%', 'growth', round(window_rate, 4) FROM sweep_growth WHERE growth = -0.03
    UNION ALL SELECT 'sweep window at 0%',  'growth', round(window_rate, 4) FROM sweep_growth WHERE growth = 0.0
    UNION ALL SELECT 'sweep window at +3%', 'growth', round(window_rate, 4) FROM sweep_growth WHERE growth = 0.03
    UNION ALL SELECT 'sweep ratio at -3%',  'growth', round(window_rate / cohort_rate, 4) FROM sweep_growth WHERE growth = -0.03
    UNION ALL SELECT 'sweep ratio at +3%',  'growth', round(window_rate / cohort_rate, 4) FROM sweep_growth WHERE growth = 0.03

    UNION ALL SELECT 'sweep cohort at m=1',  'lag', round(cohort_rate, 4) FROM sweep_lag WHERE m = 1
    UNION ALL SELECT 'sweep cohort at m=30', 'lag', round(cohort_rate, 4) FROM sweep_lag WHERE m = 30
    UNION ALL SELECT 'sweep cohort at m=60', 'lag', round(cohort_rate, 4) FROM sweep_lag WHERE m = 60
    UNION ALL SELECT 'sweep ratio at m=30',  'lag', round(window_rate / cohort_rate, 4) FROM sweep_lag WHERE m = 30
    UNION ALL SELECT 'sweep ratio at m=60',  'lag', round(window_rate / cohort_rate, 4) FROM sweep_lag WHERE m = 60
    UNION ALL SELECT 'worst truncation gap', 'lag', round(max(abs(window_rate - p)), 4) FROM sweep_lag WHERE m <= 30

    UNION ALL SELECT 'largest deviation from the derivation', 'standard errors',
        round(max(greatest(
            abs((sim_window - p_window) / sqrt(p_window * (1 - p_window) / n_window)),
            abs((sim_cohort - p_cohort) / sqrt(p_cohort * (1 - p_cohort) / n_cohort))
        )), 2)
    FROM (
        SELECT c.window_rate_closed AS p_window, r.window_rate AS sim_window,
               r.entered_in_window AS n_window, c.cohort_rate_closed AS p_cohort,
               r.cohort_rate AS sim_cohort,
               (SELECT count(*) FROM subjects s
                WHERE s.funnel = c.funnel
                  AND s.cohort_day <= (SELECT value FROM params WHERE key = 'as_of_day')
                                    - (SELECT value FROM params WHERE key = 'maturity_days')) AS n_cohort
        FROM closed_form c JOIN readings r ON r.funnel = c.funnel AND r.step = 2
    )

    UNION ALL SELECT 'dashboard at -3% over dashboard at +3%', 'spread',
        round((SELECT window_rate FROM sweep_growth WHERE growth = -0.03)
            / (SELECT window_rate FROM sweep_growth WHERE growth = 0.03), 4)

    UNION ALL SELECT 'points in the growth sweep', 'count', count(*)::DOUBLE FROM sweep_growth

    UNION ALL SELECT 'declared_mean', funnel || ' ' || stage, round(declared_mean, 4) FROM speed_ranking
    UNION ALL SELECT 'naive_mean', funnel || ' ' || stage, round(naive_mean, 2) FROM speed_ranking
    UNION ALL SELECT 'restricted_mean', funnel || ' ' || stage, round(restricted_mean, 2) FROM speed_ranking
    UNION ALL SELECT 'naive_over_declared', funnel || ' ' || stage, round(naive_over_declared, 3) FROM speed_ranking

    UNION ALL SELECT 'velocity sweep reads at -3%', 'growth', round(naive_mean, 3) FROM sweep_velocity WHERE growth = -0.03
    UNION ALL SELECT 'velocity sweep reads at 0%',  'growth', round(naive_mean, 3) FROM sweep_velocity WHERE growth = 0.0
    UNION ALL SELECT 'velocity sweep reads at +3%', 'growth', round(naive_mean, 3) FROM sweep_velocity WHERE growth = 0.03
    UNION ALL SELECT 'velocity ratio at -3%', 'growth', round(naive_mean / declared_mean, 4) FROM sweep_velocity WHERE growth = -0.03
    UNION ALL SELECT 'velocity ratio at 0%',  'growth', round(naive_mean / declared_mean, 4) FROM sweep_velocity WHERE growth = 0.0
    UNION ALL SELECT 'velocity ratio at +3%', 'growth', round(naive_mean / declared_mean, 4) FROM sweep_velocity WHERE growth = 0.03

    UNION ALL SELECT 'true speed factor', 'retencao over atendimento',
        round((SELECT declared_mean FROM speed_ranking WHERE funnel = 'retencao')
            / (SELECT declared_mean FROM speed_ranking WHERE funnel = 'atendimento'), 2)
    UNION ALL SELECT 'restricted factor', 'retencao over atendimento',
        round((SELECT restricted_mean FROM speed_ranking WHERE funnel = 'retencao')
            / (SELECT restricted_mean FROM speed_ranking WHERE funnel = 'atendimento'), 2)

    UNION ALL SELECT 'largest velocity deviation', 'standard errors',
        round(max(greatest(
            abs((v.conditional_mean - c.conditional_closed) / (v.conditional_sd / sqrt(v.conditional_n))),
            abs((v.restricted_mean - c.restricted_closed) / (v.restricted_sd / sqrt(v.subjects_at_risk)))
        )), 2)
    FROM velocity v JOIN velocity_closed_form c ON c.funnel = v.funnel WHERE v.step = 2

    -- Zero means the inversion is still there: the slowest funnel is not the one that reads slowest.
    UNION ALL SELECT 'funnel that is slowest reads slowest', 'inversion',
        CASE WHEN (SELECT funnel FROM speed_ranking WHERE rank_actually_slowest = 1)
                = (SELECT funnel FROM speed_ranking WHERE rank_reads_slowest = 1)
             THEN 1.0 ELSE 0.0 END

    UNION ALL SELECT 'subjects too young for cohorts', 'count', too_young_for_cohorts::DOUBLE FROM data_discarded
    UNION ALL SELECT 'share discarded by cohorts', 'share', round(share_discarded, 3) FROM data_discarded

    UNION ALL SELECT 'km_incidence', funnel || ' ' || stage, round(km_incidence, 4)
        FROM survival_readings WHERE step = 2
    UNION ALL SELECT 'km_standard_error', funnel || ' ' || stage, round(km_standard_error, 4)
        FROM survival_readings WHERE step = 2
    UNION ALL SELECT 'cohort_standard_error', funnel || ' ' || stage, round(cohort_standard_error, 4)
        FROM survival_readings WHERE step = 2
    UNION ALL SELECT 'standard_error_ratio', funnel || ' ' || stage, round(standard_error_ratio, 4)
        FROM survival_readings WHERE step = 2

    UNION ALL SELECT 'best error ratio', 'all stages', round(min(standard_error_ratio), 4)
        FROM survival_readings WHERE step > 1
    UNION ALL SELECT 'worst error ratio', 'all stages', round(max(standard_error_ratio), 4)
        FROM survival_readings WHERE step > 1
    UNION ALL SELECT 'mean equivalent sample', 'all stages',
        round(avg(1.0 / pow(standard_error_ratio, 2)), 2) FROM survival_readings WHERE step > 1
    UNION ALL SELECT 'demanda equivalent sample', 'classificada',
        round(1.0 / pow(standard_error_ratio, 2), 3) FROM survival_readings
        WHERE funnel = 'demanda' AND step = 2

    UNION ALL SELECT 'largest survival deviation', 'standard errors',
        round(max(abs(v.km_incidence - c.incidence_closed) / v.km_standard_error), 2)
        FROM survival_readings v JOIN survival_closed_form c ON c.funnel = v.funnel WHERE v.step = 2
    UNION ALL SELECT 'worst half-life gap', 'relative',
        round(max(abs(v.half_life_days / c.half_life_closed - 1.0)), 4)
        FROM survival_readings v JOIN survival_closed_form c ON c.funnel = v.funnel WHERE v.step = 2

    UNION ALL SELECT 'stages with no median', 'count',
        count(*) FILTER (WHERE median_days IS NULL)::DOUBLE FROM survival_readings WHERE step > 1
    UNION ALL SELECT 'stages beyond entry', 'count', count(*)::DOUBLE
        FROM survival_readings WHERE step > 1

    UNION ALL SELECT 'plateau_incidence', funnel || ' ' || stage, round(plateau_incidence, 4)
        FROM survival_readings WHERE step > 1
    UNION ALL SELECT 'half_life_days', funnel || ' ' || stage, round(half_life_days, 3)
        FROM survival_readings WHERE step > 1

    UNION ALL SELECT 'mixture mean multiplier', 'exact', round(sum(share * multiplier), 4) FROM frailty
    UNION ALL SELECT 'slow class multiplier', 'declared', round(multiplier, 4) FROM frailty WHERE class = 'slow'
    UNION ALL SELECT 'fast class multiplier', 'declared', round(multiplier, 4) FROM frailty WHERE class = 'fast'
    UNION ALL SELECT 'realised slow share', 'observed',
        round(count(*) FILTER (WHERE class = 'slow') / count(*)::DOUBLE, 4) FROM subject_class

    UNION ALL SELECT 'largest mixture deviation', 'standard errors', round(max(abs(z)), 2)
    FROM (
        SELECT (k.incidence - c.incidence_closed)
             / sqrt(c.incidence_closed * (1 - c.incidence_closed)
                    / (SELECT count(*) FROM subjects s WHERE s.funnel = c.funnel)) AS z
        FROM frailty_closed_form c
        JOIN (
            SELECT funnel, step, incidence FROM frail_survival
            WHERE time <= (SELECT value FROM params WHERE key = 'maturity_days')
            QUALIFY time = max(time) OVER (PARTITION BY funnel, step)
        ) k ON k.funnel = c.funnel AND k.step = 2
    )

    UNION ALL SELECT 'observed mean, one exponential', funnel, round(observed_mean, 4)
        FROM (SELECT funnel, avg(age_at_stage) AS observed_mean FROM events
              WHERE step = 2 AND observed GROUP BY 1) WHERE funnel = 'retencao'
    UNION ALL SELECT 'observed mean, two classes', funnel, round(observed_mean, 4)
        FROM (SELECT funnel, avg(age_at_stage) AS observed_mean FROM frail_events
              WHERE step = 2 AND observed GROUP BY 1) WHERE funnel = 'retencao'
    UNION ALL SELECT 'observed mean ratio', b.funnel, round(f.m / b.m, 4)
        FROM (SELECT funnel, avg(age_at_stage) AS m FROM events WHERE step = 2 AND observed GROUP BY 1) b
        JOIN (SELECT funnel, avg(age_at_stage) AS m FROM frail_events WHERE step = 2 AND observed GROUP BY 1) f
          USING (funnel)

    UNION ALL SELECT 'records archived', 'at 21 days', count(*)::DOUBLE FROM archive_decisions
    UNION ALL SELECT 'share of archived that are slow', 'at 21 days',
        round(count(*) FILTER (WHERE class = 'slow') / count(*)::DOUBLE, 4) FROM archive_decisions
    UNION ALL SELECT 'review selectivity', 'slow over population',
        round((SELECT count(*) FILTER (WHERE class = 'slow') / count(*)::DOUBLE FROM archive_decisions)
            / (SELECT count(*) FILTER (WHERE class = 'slow') / count(*)::DOUBLE FROM subject_class), 4)

    UNION ALL SELECT 'sweep ratio', funnel || ' at ' || stale_days::INTEGER || ' days', round(ratio, 4)
        FROM sweep_archiving WHERE funnel IN ('retencao', 'venda') AND stale_days IN (3, 7, 14, 21)

    UNION ALL SELECT 'sweep points at or beyond the horizon', 'count', count(*)::DOUBLE
        FROM sweep_archiving WHERE stale_days >= 30
    UNION ALL SELECT 'unbiased at or beyond the horizon', 'count',
        count(*) FILTER (WHERE abs(ratio - 1.0) < 1e-9)::DOUBLE
        FROM sweep_archiving WHERE stale_days >= 30
    UNION ALL SELECT 'sweep points inside the horizon', 'count', count(*)::DOUBLE
        FROM sweep_archiving WHERE stale_days < 30
    UNION ALL SELECT 'unbiased inside the horizon', 'count',
        count(*) FILTER (WHERE abs(ratio - 1.0) < 1e-9)::DOUBLE
        FROM sweep_archiving WHERE stale_days < 30
    UNION ALL SELECT 'sweep points above one inside', 'count',
        count(*) FILTER (WHERE ratio > 1.0 + 1e-9)::DOUBLE FROM sweep_archiving WHERE stale_days < 30
    UNION ALL SELECT 'sweep points below one inside', 'count',
        count(*) FILTER (WHERE ratio < 1.0 - 1e-9)::DOUBLE FROM sweep_archiving WHERE stale_days < 30
)
SELECT 'a published figure moved' AS failure,
       e.what || ' / ' || e.detail AS detail,
       e.value AS published,
       m.value AS measured
FROM expected e
LEFT JOIN measured m ON m.what = e.what AND m.detail = e.detail
WHERE m.value IS NULL OR abs(m.value - e.value) > 5e-5;
