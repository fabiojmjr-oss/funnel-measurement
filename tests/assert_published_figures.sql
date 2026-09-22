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
    ('points in the growth sweep',            'count',          61.0000)
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
)
SELECT 'a published figure moved' AS failure,
       e.what || ' / ' || e.detail AS detail,
       e.value AS published,
       m.value AS measured
FROM expected e
LEFT JOIN measured m ON m.what = e.what AND m.detail = e.detail
WHERE m.value IS NULL OR abs(m.value - e.value) > 5e-5;
