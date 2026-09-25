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

    -- Wave 5, the queue. Per-class waits under the three disciplines.
    ('queue wait',      'fifo p1',            2.5461),
    ('queue wait',      'fifo p2',            2.5624),
    ('queue wait',      'fifo p3',            2.5632),
    ('queue wait',      'priority p1',        0.6961),
    ('queue wait',      'priority p2',        1.1636),
    ('queue wait',      'priority p3',        4.3583),
    ('queue wait',      'reversed p1',        6.7375),
    ('queue wait',      'reversed p2',        2.3953),
    ('queue wait',      'reversed p3',        0.9051),

    -- The two totals: one moves with the discipline and one does not.
    ('queue reported mean',  'fifo',          2.5612),
    ('queue reported mean',  'priority',      3.0358),
    ('queue reported mean',  'reversed',      1.9382),
    ('queue reported ratio', 'priority',      1.1853),
    ('queue reported ratio', 'reversed',      0.7568),
    ('queue reported ratio', 'priority over reversed', 1.5663),
    ('queue invariant mean', 'fifo',          2.5540477739),
    ('queue invariant mean', 'priority',      2.5540477739),
    ('queue invariant mean', 'reversed',      2.5540477739),

    -- The derivations the simulation is checked against.
    ('queue derived wait', 'fifo',            2.5868),
    ('queue derived wait', 'priority p1',     0.6705),
    ('queue derived wait', 'priority p2',     1.1473),
    ('queue derived wait', 'priority p3',     4.4261),
    ('queue derived wait', 'reversed p1',     6.9737),
    ('queue derived wait', 'reversed p2',     2.4147),
    ('queue derived wait', 'reversed p3',     0.8957),
    ('queue worst deviation', 'standard errors', 1.293),

    -- Service levels, and the ceiling no ordering can pass.
    ('queue sla met',  'fifo p1',             0.3752),
    ('queue sla met',  'fifo p3',             0.8486),
    ('queue sla met',  'priority p1',         0.6295),
    ('queue sla met',  'priority p3',         0.7264),
    ('queue sla met',  'reversed p1',         0.3207),
    ('queue sla met',  'reversed p3',         0.9925),
    ('queue sla ceiling', 'p1',               0.7956),

    -- The utilisation sweep and its elasticity.
    ('queue sweep wait', '0.40',              0.4925),
    ('queue sweep wait', '0.50',              0.7408),
    ('queue sweep wait', '0.78',              2.5957),
    ('queue sweep wait', '0.90',              6.8417),
    ('queue sweep wait', '0.98',             24.2435),
    ('queue elasticity', '0.78',              4.545),

    -- Run length against the truth: nine readings, all of them low.
    ('queue run length ratio', '0.78 at 5000',   0.7048),
    ('queue run length ratio', '0.78 at 20000',  0.9847),
    ('queue run length ratio', '0.78 at 60000',  0.9873),
    ('queue run length ratio', '0.95 at 5000',   0.4289),
    ('queue run length ratio', '0.95 at 20000',  0.9367),
    ('queue run length ratio', '0.95 at 60000',  0.9641),
    ('queue run length ratio', '0.98 at 5000',   0.2442),
    ('queue run length ratio', '0.98 at 20000',  0.6238),
    ('queue run length ratio', '0.98 at 60000',  0.8422),
    ('queue biggest period share', '0.98 at 60000', 0.2121),
    ('queue biggest period',       '0.98 at 60000', 12724.0),

    -- What one 180-day slice can say.
    ('queue slices',              'count',       277.0),
    ('queue demands per slice',   'mean',        216.6),
    ('queue true mean wait',      'slices',        2.5318),
    ('queue lowest slice',        'mean wait',     0.6441),
    ('queue highest slice',       'mean wait',     9.3057),
    ('queue widest pair',         'ratio',        14.4486),
    ('queue naive half width',    'days',          0.6925),
    ('queue honest half width',   'days',          5.8781),
    ('queue interval understated','times',         8.4879),

    -- And the interval itself.
    ('queue standard error inflation', 'lowest',  1.482),
    ('queue standard error inflation', 'highest', 6.362),
    ('queue detectable error', 'clustered lowest',  0.0701),
    ('queue detectable error', 'clustered highest', 0.2023),
    ('queue detectable error', 'naive lowest',      0.0257),

    -- Wave 6, the triage desk. What is in each label.
    ('triage labelled',        'p1',                10084.0),
    ('triage labelled',        'p2',                22600.0),
    ('triage labelled',        'p3',                27316.0),
    ('triage label share',     'p1',                    0.1681),
    ('triage label share',     'p2',                    0.3767),
    ('triage label share',     'p3',                    0.4553),
    ('triage label purity',    'p1',                    0.4509),
    ('triage label purity',    'p2',                    0.5905),
    ('triage label purity',    'p3',                    0.9215),
    ('triage from own class',  'p1',                 4547.0),
    ('triage from others',     'p1',                 5537.0),

    -- What the labelling costs each class.
    ('triage wait',            'p1',                    1.0383),
    ('triage wait',            'p2',                    1.6401),
    ('triage wait',            'p3',                    3.8716),
    ('triage ratio',           'p1',                    1.4916),
    ('triage ratio',           'p2',                    1.4095),
    ('triage ratio',           'p3',                    0.8883),
    ('triage sla met',         'p1',                    0.5941),

    -- And the invariance surviving the relabelling.
    ('triage work weighted',   'total',             99015.6062),
    ('triage work weighted',   'against perfect',       1.0),
    ('triage reported mean',   'per demand',            2.9201),

    -- Cobham on the labels, and the composition onto the classes.
    ('triage label derived',   'p1',                    0.6957),
    ('triage label derived',   'p2',                    1.3640),
    ('triage label derived',   'p3',                    5.0720),
    ('triage label simulated', 'p1',                    0.7042),
    ('triage label simulated', 'p2',                    1.3984),
    ('triage label simulated', 'p3',                    4.9970),
    ('triage class derived',   'p1',                    1.0482),
    ('triage worst deviation', 'standard errors',       0.867),

    -- The six orders, and what the dashboard says about them.
    ('order cost',             'p1 p2 p3',              5.2657),
    ('order cost',             'p2 p1 p3',              5.6603),
    ('order cost',             'p1 p3 p2',              7.5822),
    ('order cost',             'p3 p1 p2',              8.6627),
    ('order cost',             'p2 p3 p1',             10.8461),
    ('order cost',             'p3 p2 p1',             11.7533),
    ('order against best',     'p2 p1 p3',              1.0749),
    ('order against best',     'p1 p3 p2',              1.4399),
    ('order against best',     'p3 p1 p2',              1.6451),
    ('order against best',     'p2 p3 p1',              2.0598),
    ('order against best',     'p3 p2 p1',              2.2321),
    ('order reported mean',    'p1 p2 p3',              3.0691),
    ('order reported mean',    'p2 p1 p3',              3.0240),
    ('order reported mean',    'p1 p3 p2',              2.4900),
    ('order reported mean',    'p3 p1 p2',              2.3160),
    ('order reported mean',    'p2 p3 p1',              2.1891),
    ('order reported mean',    'p3 p2 p1',              1.9622),
    ('order work weighted',    'p1 p2 p3',              2.0174602407),
    ('order work weighted',    'p3 p2 p1',              2.0174602407),

    -- The two error directions.
    ('escalation ratio',       'over 0.05',             1.0385),
    ('escalation ratio',       'over 0.10',             1.0800),
    ('escalation ratio',       'over 0.20',             1.1739),
    ('escalation ratio',       'over 0.50',             1.5883),
    ('escalation ratio',       'over 1.00',             3.8580),
    ('escalation ratio',       'under 0.05',            1.2675),
    ('escalation ratio',       'under 0.10',            1.5278),
    ('escalation ratio',       'under 0.20',            2.0280),
    ('escalation ratio',       'under 0.50',            3.3826),
    ('escalation ratio',       'under 1.00',            5.2470),
    ('escalation crossover',   'rate',                  0.62),

    -- The rule, its margins, and where it breaks.
    ('urgency per handling',   'p1',                    8.0768),
    ('urgency per handling',   'p2',                    4.0797),
    ('urgency per handling',   'p3',                    1.9904),
    ('handling mean',          'p1',                    1.2381),
    ('handling mean',          'p2',                    0.7353),
    ('handling mean',          'p3',                    0.5024),
    ('order swap margin',      'p1',                    1.9797),
    ('order swap margin',      'p2',                    2.0497),
    ('handling swap point',    'days',                  2.4512),
    ('critical first cost',    '0.5000',                0.8046),
    ('critical first cost',    '1.2380',                0.9303),
    ('critical first cost',    '2.4000',                0.9982),
    ('critical first cost',    '2.5000',                1.0016),
    ('critical first cost',    '6.0000',                1.0544),

    -- And the two levers.
    ('lever cost',             'perfect triage best order', 5.2657),
    ('lever cost',             'imperfect triage',          1.1157),
    ('lever cost',             'next best order',           1.0749),
    ('lever cost',             'worst order',               2.2321),
    ('lever cost',             'critical class',            1.5632),

    -- Wave 7, what triage costs. Accuracy derived from effort.
    ('effort accuracy', 'urgent 1 p1',   0.7000),
    ('effort accuracy', 'urgent 2 p1',   0.9100),
    ('effort accuracy', 'urgent 2 p3',   0.4900),
    ('effort accuracy', 'urgent 3 p1',   0.8785),
    ('effort accuracy', 'urgent 3 p3',   0.7840),
    ('effort accuracy', 'urgent 4 p2',   0.8501),
    ('effort accuracy', 'urgent 4 p3',   0.7840),
    ('effort accuracy', 'urgent 8 p1',   0.9712),
    ('effort accuracy', 'urgent 8 p2',   0.9481),
    ('effort accuracy', 'urgent 8 p3',   0.9250),
    ('effort accuracy', 'lenient 2 p1',  0.4900),
    ('effort accuracy', 'lenient 2 p3',  0.9100),
    ('effort worst deviation', 'standard errors', 2.093),

    -- What the looking costs the server.
    ('effort utilisation', '0',          0.7799),
    ('effort utilisation', '1',          0.8040),
    ('effort utilisation', '2',          0.8282),
    ('effort utilisation', '3',          0.8523),
    ('effort utilisation', '5',          0.9006),
    ('effort utilisation', '8',          0.9730),
    ('effort wait without priority', '8', 26.3007),
    ('effort triage days', '8',          0.16),

    -- The trade, and the interior optimum.
    ('effort critical wait', '1',        1.5789),
    ('effort critical wait', '2',        1.1868),
    ('effort critical wait', '3',        1.3364),
    ('effort critical wait', '5',        1.2124),
    ('effort critical wait', '8',        1.5938),
    ('effort improvement wait', '1',     4.3030),
    ('effort improvement wait', '2',     5.3872),
    ('effort improvement wait', '3',     6.8672),
    ('effort improvement wait', '5',    11.7301),
    ('effort improvement wait', '8',    51.0349),
    ('effort cost', 'urgent 0',          7.8212),
    ('effort cost', 'urgent 1',          7.1449),
    ('effort cost', 'urgent 2',          7.6569),
    ('effort cost', 'urgent 3',          8.7071),
    ('effort cost', 'urgent 5',         12.1307),
    ('effort cost', 'urgent 8',         41.6458),
    ('effort cost', 'lenient 2',         8.5145),
    ('effort against no triage', 'urgent 1', 0.9135),
    ('effort against no triage', 'urgent 2', 0.9790),
    ('effort against no triage', 'urgent 3', 1.1133),
    ('effort against no triage', 'urgent 5', 1.5510),
    ('effort against no triage', 'urgent 8', 5.3248),

    -- And the effort worth spending, against the utilisation already carried.
    ('effort best looks', '0.40',        1.0),
    ('effort best looks', '0.75',        1.0),
    ('effort best looks', '0.88',        1.0),
    ('effort best looks', '0.89',        0.0),
    ('effort best looks', '0.95',        0.0),
    ('effort optimum gain', '0.40',      0.9629),
    ('effort optimum gain', '0.60',      0.9268),
    ('effort optimum gain', '0.75',      0.9112),
    ('effort optimum gain', '0.85',      0.9451),
    ('effort optimum gain', '0.88',      0.9874),
    ('effort feasible looks', '0.78',    8.0),
    ('effort feasible looks', '0.85',    5.0),
    ('effort feasible looks', '0.88',    4.0),
    ('effort feasible looks', '0.95',    1.0),

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

    UNION ALL SELECT 'queue wait', discipline || ' ' || priority, round(mean_wait, 4) FROM queue_readings
    UNION ALL SELECT 'queue sla met', discipline || ' ' || priority, round(sla_met, 4) FROM queue_readings
    UNION ALL SELECT 'queue sla ceiling', priority, round(sla_met_without_waiting, 4)
        FROM queue_readings WHERE discipline = 'fifo'
    UNION ALL SELECT 'queue standard error inflation', 'lowest', round(min(standard_error_inflation), 3)
        FROM queue_readings
    UNION ALL SELECT 'queue standard error inflation', 'highest', round(max(standard_error_inflation), 3)
        FROM queue_readings

    UNION ALL SELECT 'queue reported mean', discipline, round(mean_wait_per_demand, 4) FROM queue_totals
    UNION ALL SELECT 'queue invariant mean', discipline, round(mean_wait_per_day_of_work, 10)
        FROM queue_totals
    UNION ALL SELECT 'queue reported ratio', discipline, round(reported_ratio, 4)
        FROM queue_conservation WHERE discipline <> 'fifo'
    UNION ALL SELECT 'queue reported ratio', 'priority over reversed',
        round((SELECT mean_wait_per_demand FROM queue_totals WHERE discipline = 'priority')
              / (SELECT mean_wait_per_demand FROM queue_totals WHERE discipline = 'reversed'), 4)

    UNION ALL SELECT 'queue derived wait', 'fifo', round(max(derived_wait), 4)
        FROM queue_closed_form WHERE discipline = 'fifo'
    UNION ALL SELECT 'queue derived wait', discipline || ' ' || priority, round(derived_wait, 4)
        FROM queue_closed_form WHERE discipline <> 'fifo'
    UNION ALL SELECT 'queue worst deviation', 'standard errors',
        round(max(abs((simulated_wait - derived_wait) / wait_standard_error)), 3) FROM queue_closed_form

    UNION ALL SELECT 'queue detectable error', 'clustered lowest',
        round(min(4.0 * q.wait_standard_error / c.derived_wait), 4)
        FROM queue_readings q JOIN queue_closed_form c
          ON c.discipline = q.discipline AND c.priority = q.priority
    UNION ALL SELECT 'queue detectable error', 'clustered highest',
        round(max(4.0 * q.wait_standard_error / c.derived_wait), 4)
        FROM queue_readings q JOIN queue_closed_form c
          ON c.discipline = q.discipline AND c.priority = q.priority
    UNION ALL SELECT 'queue detectable error', 'naive lowest',
        round(min(4.0 * q.naive_standard_error / c.derived_wait), 4)
        FROM queue_readings q JOIN queue_closed_form c
          ON c.discipline = q.discipline AND c.priority = q.priority

    UNION ALL SELECT 'queue sweep wait', utilisation::VARCHAR, round(mean_wait_per_day_of_work, 4)
        FROM queue_sweep_closed_form WHERE discipline = 'fifo'
    UNION ALL SELECT 'queue elasticity', utilisation::VARCHAR, round(elasticity_of_waiting_in_demand, 3)
        FROM queue_sweep_closed_form WHERE discipline = 'fifo'

    UNION ALL SELECT 'queue run length ratio', utilisation || ' at ' || run_length,
        round(mean_wait_per_day_of_work / derived_wait, 4) FROM queue_run_length
    UNION ALL SELECT 'queue biggest period share', utilisation || ' at ' || run_length,
        round(biggest_share_of_run, 4) FROM queue_run_length
    UNION ALL SELECT 'queue biggest period', utilisation || ' at ' || run_length,
        biggest_busy_period::DOUBLE FROM queue_run_length

    UNION ALL SELECT 'queue slices', 'count', slices::DOUBLE FROM queue_measurability
    UNION ALL SELECT 'queue demands per slice', 'mean', round(mean_demands_per_slice, 1)
        FROM queue_measurability
    UNION ALL SELECT 'queue true mean wait', 'slices', round(mean_of_slice_means, 4) FROM queue_measurability
    UNION ALL SELECT 'queue lowest slice', 'mean wait', round(lowest_slice_mean, 4) FROM queue_measurability
    UNION ALL SELECT 'queue highest slice', 'mean wait', round(highest_slice_mean, 4) FROM queue_measurability
    UNION ALL SELECT 'queue widest pair', 'ratio', round(widest_pair_of_readings, 4) FROM queue_measurability
    UNION ALL SELECT 'queue naive half width', 'days', round(naive_half_width, 4) FROM queue_measurability
    UNION ALL SELECT 'queue honest half width', 'days', round(honest_half_width, 4) FROM queue_measurability
    UNION ALL SELECT 'queue interval understated', 'times', round(interval_understated_by, 4)
        FROM queue_measurability

    UNION ALL SELECT 'triage labelled', assigned_priority, labelled::DOUBLE FROM triage_purity
    UNION ALL SELECT 'triage label share', assigned_priority, round(share_of_all_demands, 4)
        FROM triage_purity
    UNION ALL SELECT 'triage label purity', assigned_priority, round(share_correctly_labelled, 4)
        FROM triage_purity
    UNION ALL SELECT 'triage from own class', assigned_priority, demands_from_its_own_class::DOUBLE
        FROM triage_purity WHERE assigned_priority = 'p1'
    UNION ALL SELECT 'triage from others', assigned_priority, demands_from_other_classes::DOUBLE
        FROM triage_purity WHERE assigned_priority = 'p1'

    UNION ALL SELECT 'triage wait', priority, round(wait_under_real_triage, 4) FROM triage_damage
    UNION ALL SELECT 'triage ratio', priority,
        round(wait_under_real_triage / wait_under_perfect_triage, 4) FROM triage_damage
    UNION ALL SELECT 'triage sla met', priority, round(sla_under_real_triage, 4)
        FROM triage_damage WHERE priority = 'p1'

    UNION ALL SELECT 'triage work weighted', 'total', round(work_weighted_wait, 4) FROM triage_totals
    UNION ALL SELECT 'triage work weighted', 'against perfect',
        round(t.work_weighted_wait / q.work_weighted_wait, 12)
        FROM triage_totals t, queue_totals q WHERE q.discipline = 'priority'
    UNION ALL SELECT 'triage reported mean', 'per demand', round(mean_wait_per_demand, 4)
        FROM triage_totals

    UNION ALL SELECT 'triage label derived', priority, round(derived_wait, 4)
        FROM triage_label_closed_form
    UNION ALL SELECT 'triage label simulated', priority, round(simulated_wait, 4)
        FROM triage_label_closed_form
    UNION ALL SELECT 'triage class derived', priority, round(derived_wait, 4)
        FROM triage_closed_form WHERE priority = 'p1'
    UNION ALL SELECT 'triage worst deviation', 'standard errors', round(worst, 3) FROM (
        SELECT greatest(
            (SELECT max(abs((simulated_wait - derived_wait) / wait_standard_error))
             FROM triage_label_closed_form),
            (SELECT max(abs((simulated_wait - derived_wait) / wait_standard_error))
             FROM triage_closed_form)) AS worst
    )

    UNION ALL SELECT 'order cost', ordering, round(weighted_waiting, 4) FROM urgency_orders
    UNION ALL SELECT 'order against best', ordering,
        round(weighted_waiting / min(weighted_waiting) OVER (), 4) FROM urgency_orders
    UNION ALL SELECT 'order reported mean', ordering, round(mean_wait_per_demand, 4) FROM urgency_orders
    UNION ALL SELECT 'order work weighted', ordering, round(work_weighted_waiting, 10)
        FROM urgency_orders

    UNION ALL SELECT 'escalation ratio', direction || ' ' || rate,
        round(critical_wait / (SELECT derived_wait FROM queue_closed_form
                               WHERE discipline = 'priority' AND priority = 'p1'), 4)
        FROM escalation_sweep
    UNION ALL SELECT 'escalation crossover', 'rate', min(under_recognition_rate)::DOUBLE
        FROM escalation_crossover WHERE critical_wait > wait_with_no_priority_at_all

    UNION ALL SELECT 'urgency per handling', priority, round(cost_per_day_of_handling, 4) FROM urgency_rule
    UNION ALL SELECT 'handling mean', priority, round(realised_service_mean, 4) FROM urgency_rule
    UNION ALL SELECT 'order swap margin', priority, round(margin_before_the_order_swaps, 4)
        FROM urgency_rule WHERE margin_before_the_order_swaps IS NOT NULL
    UNION ALL SELECT 'handling swap point', 'days', round(max(handling_at_which_the_order_swaps), 4)
        FROM urgency_sweep
    UNION ALL SELECT 'critical first cost', format('{:.4f}', critical_handling_days),
        round(weighted_critical_first / weighted_standard_first, 4) FROM urgency_sweep

    UNION ALL SELECT 'lever cost', 'perfect triage best order', round(weighted_perfect, 4) FROM triage_cost
    UNION ALL SELECT 'lever cost', 'imperfect triage', round(weighted_real / weighted_perfect, 4)
        FROM triage_cost
    UNION ALL SELECT 'lever cost', 'next best order', round(cost_of_the_next_best_order, 4) FROM triage_cost
    UNION ALL SELECT 'lever cost', 'worst order', round(cost_of_the_worst_order, 4) FROM triage_cost
    UNION ALL SELECT 'lever cost', 'critical class',
        round(cost_of_imperfect_triage_to_the_critical_class, 4) FROM triage_cost

    UNION ALL SELECT 'effort accuracy', tie_break || ' ' || looks || ' ' || true_priority,
        round(probability, 4) FROM effort_confusion WHERE true_priority = assigned_priority
    UNION ALL SELECT 'effort worst deviation', 'standard errors', round(worst, 3) FROM (
        SELECT max(abs(d.drawn_probability - c.probability)
                   / sqrt(c.probability * (1.0 - c.probability) / n.from_class)) AS worst
        FROM effort_confusion_draw d
        JOIN effort_confusion c
          ON c.looks = (SELECT value FROM queue_effort WHERE key = 'declared_looks')::INTEGER
         AND c.tie_break = d.tie_break AND c.true_priority = d.true_priority
         AND c.assigned_priority = d.assigned_priority
        JOIN (SELECT tie_break, true_priority, sum(demands) AS from_class
              FROM effort_confusion_draw GROUP BY 1, 2) n
          ON n.tie_break = d.tie_break AND n.true_priority = d.true_priority
    )

    UNION ALL SELECT 'effort utilisation', looks::VARCHAR, round(utilisation, 4) FROM effort_capacity
    UNION ALL SELECT 'effort wait without priority', looks::VARCHAR, round(wait_without_priority, 4)
        FROM effort_capacity
    UNION ALL SELECT 'effort triage days', looks::VARCHAR, round(triage_days_per_demand, 4)
        FROM effort_capacity

    UNION ALL SELECT 'effort critical wait', looks::VARCHAR, round(critical_wait, 4)
        FROM effort_cost WHERE tie_break = 'urgent'
    UNION ALL SELECT 'effort improvement wait', looks::VARCHAR, round(improvement_wait, 4)
        FROM effort_cost WHERE tie_break = 'urgent'
    UNION ALL SELECT 'effort cost', tie_break || ' ' || looks, round(weighted_waiting, 4) FROM effort_cost
    UNION ALL SELECT 'effort against no triage', tie_break || ' ' || looks, round(against_no_triage, 4)
        FROM effort_cost

    UNION ALL SELECT 'effort best looks', base_utilisation::VARCHAR, best_looks::DOUBLE
        FROM effort_optimum WHERE tie_break = 'urgent'
    UNION ALL SELECT 'effort optimum gain', base_utilisation::VARCHAR, round(against_no_triage, 4)
        FROM effort_optimum WHERE tie_break = 'urgent'
    UNION ALL SELECT 'effort feasible looks', base_utilisation::VARCHAR, most_looks_feasible::DOUBLE
        FROM effort_optimum WHERE tie_break = 'urgent'
)
SELECT 'a published figure moved' AS failure,
       e.what || ' / ' || e.detail AS detail,
       e.value AS published,
       m.value AS measured
FROM expected e
LEFT JOIN measured m ON m.what = e.what AND m.detail = e.detail
WHERE m.value IS NULL OR abs(m.value - e.value) > 5e-5;
