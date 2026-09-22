-- Every number this repository publishes comes from this file.
--
-- Nothing here is fitted to anything. These are declared parameters of an invented company, and the
-- point of writing them down in one place is that a reader can change one and watch every published
-- figure move. No employer, client, customer or vendor data appears anywhere - see DISCLAIMER.md.

CREATE OR REPLACE TABLE params AS
SELECT * FROM (VALUES
    ('as_of_day',      180, 'Last day of the observation window. Anything later has not happened yet.'),
    ('window_days',     30, 'Length of the reporting window a dashboard shows.'),
    ('maturity_days',   30, 'Days a cohort is given to convert before it is read. The same length as the window on purpose, so the two funnels are answering the same question.'),
    ('rng_rounds',       4, 'Mixing rounds in the declared generator. Written down because a generator nobody can read is a figure nobody can reproduce.')
) AS t(key, value, note);

-- The six funnels a mature company runs. One row each, and the growth rate is the parameter that
-- makes wave 1's finding appear: it is the only thing that differs between a funnel that looks like
-- it is getting worse and one that looks like it is getting better.
CREATE OR REPLACE TABLE funnels AS
SELECT * FROM (VALUES
    ('venda',       1, 'Sales',              'Venda',                  12.0,  0.012),
    ('ativacao',    2, 'Activation',         'Ativacao',               10.0,  0.008),
    ('retencao',    3, 'Retention',          'Retencao',               25.0,  0.000),
    ('resgate',     4, 'Winback',            'Resgate de churn',       30.0, -0.009),
    ('atendimento', 5, 'Service',            'Atendimento',            60.0,  0.003),
    ('demanda',     6, 'Demand intake',      'Tratamento de demandas',  8.0,  0.020)
) AS t(funnel, position, label_en, label_pt, arrivals_base, arrivals_growth_daily);

-- The stages, in order. Step 1 is entry: everybody who arrives is in it, at no delay, which is why
-- its pass rate is one and its lag is zero. Every later step carries the chance of getting there
-- from the step before and the mean delay of doing so.
CREATE OR REPLACE TABLE stages AS
SELECT * FROM (VALUES
    ('venda',       1, 'lead',           1.00,  0.0),
    ('venda',       2, 'qualificado',    0.45,  2.0),
    ('venda',       3, 'proposta',       0.55,  5.0),
    ('venda',       4, 'negociacao',     0.62,  7.0),
    ('venda',       5, 'fechado',        0.48,  9.0),

    ('ativacao',    1, 'contratado',     1.00,  0.0),
    ('ativacao',    2, 'configurado',    0.78,  3.0),
    ('ativacao',    3, 'primeiro-uso',   0.71,  4.0),
    ('ativacao',    4, 'uso-recorrente', 0.54, 12.0),

    ('retencao',    1, 'ativo',          1.00,  0.0),
    ('retencao',    2, 'em-risco',       0.22, 20.0),
    ('retencao',    3, 'contato-feito',  0.68,  4.0),
    ('retencao',    4, 'renovado',       0.74,  6.0),

    ('resgate',     1, 'perdido',        1.00,  0.0),
    ('resgate',     2, 'elegivel',       0.61, 10.0),
    ('resgate',     3, 'abordado',       0.83,  6.0),
    ('resgate',     4, 'respondeu',      0.29,  5.0),
    ('resgate',     5, 'reativado',      0.41,  8.0),

    ('atendimento', 1, 'aberto',         1.00,  0.0),
    ('atendimento', 2, 'triado',         0.96,  0.2),
    ('atendimento', 3, 'em-atendimento', 0.92,  0.6),
    ('atendimento', 4, 'resolvido',      0.85,  1.4),
    ('atendimento', 5, 'confirmado',     0.63,  3.0),

    ('demanda',     1, 'registrada',     1.00,  0.0),
    ('demanda',     2, 'classificada',   0.94,  1.0),
    ('demanda',     3, 'priorizada',     0.72,  3.0),
    ('demanda',     4, 'em-execucao',    0.66,  8.0),
    ('demanda',     5, 'entregue',       0.79, 15.0)
) AS t(funnel, step, stage, pass_rate, lag_mean_days);

-- Two classes of subject, because an exponential delay has no memory and that is what protects the
-- estimator of wave 3.
--
-- Under one exponential, a subject that has been open for twenty days is exactly as likely to convert
-- tomorrow as one that opened this morning. So removing a subset of the slow ones removes nothing the
-- estimator needed: the survivors have the same future as the departed. That memorylessness is why
-- wave 3 could not be broken by archiving alone, and it is also an assumption no funnel satisfies -
-- some deals move and some drag, and the ones that drag were always going to.
--
-- The mixture below is the smallest departure that has both a closed form and the property that
-- matters: the two classes have **the same mean delay** as the single exponential they replace, so
-- nothing about the average speed of the funnel changes. Only the spread does, and the spread is what
-- selective censoring can see.
--
--   0.30 * 2.5 + 0.70 * (1 - 0.30 * 2.5) / 0.70 = 1.0
CREATE OR REPLACE TABLE frailty AS
SELECT * FROM (VALUES
    ('slow', 0.30, 2.500000),
    ('fast', 0.70, 0.357143)
) AS t(class, share, multiplier);

-- The pipeline review that archives what looks dead, and the reason it is dangerous.
--
-- A first attempt at this parameter archived every subject still open after `stale_days` with one
-- probability. That does **not** break wave 3's estimator, and working out why is the wave: conditional
-- on being open at day twenty-one, archiving a random share removes a representative sample of the
-- subjects at risk, so the survivors really do stand for the departed and the estimator is entitled to
-- assume it. A censoring rate that depends only on elapsed time is exactly what the method allows.
--
-- What breaks it is **judgement**. A pipeline review does not archive by stopwatch; somebody looks at
-- the record, asks the account manager, and closes the ones that are genuinely dead. That judgement
-- correlates with the class - the thing that makes a subject slow in the first place - so the subjects
-- removed are not a representative sample of the ones still open, and the survivors are faster than the
-- departed. The class is unobservable, which is why an analyst cannot see any of this from inside the
-- data: all they see is a censoring.
CREATE OR REPLACE TABLE archiving AS
SELECT * FROM (VALUES
    (21.0, 0.60, 0.10)
) AS t(stale_days, archive_probability_slow, archive_probability_fast);

-- The generator, written in arithmetic rather than delegated to a library.
--
-- A sibling repository of mine published figures that held on one machine and moved on a clean
-- install, because the library's sampler consumed a variable number of uniforms per draw. The lesson
-- carried here is stronger than the fix: a seeded `random()` is a promise made by whichever version
-- of the engine happens to be installed, and this file cannot make that promise. So the uniform is a
-- counter-based mix of the draw's own index - no state, no seed to forget, and nothing that depends
-- on the order rows happen to be evaluated in.
--
-- The first version of this macro was three Lehmer steps on `index * 48271 + salt * 7919`. It passed
-- the obvious test - the mean sat on 0.49999 and the range filled the interval - and it was badly
-- broken: two streams on the same index correlated at **-0.42**, because a purely multiplicative
-- generator turns an additive difference between salts into a fixed offset. The uniformity of one
-- stream says nothing about the independence of two, and this repository needs the second thing.
--
-- What is here now interleaves a shift-and-xor with the multiply, which breaks that linearity. The
-- measured numbers, asserted in tests/assert_generator.sql: decile counts within 0.8% of a tenth,
-- the largest absolute correlation across 55 pairs of streams 0.0109, and lag-one autocorrelation
-- -0.0004. 2147483647 is the Mersenne prime 2^31 - 1 and 48271 is one of its standard multipliers;
-- every intermediate product stays under 1.1e14, well inside BIGINT, which is what the modulus is
-- for.
CREATE OR REPLACE MACRO mix31(x) AS (xor(x::BIGINT, x::BIGINT >> 13) * 48271 % 2147483647);

CREATE OR REPLACE MACRO u01(counter, salt) AS
    mix31(mix31((counter::BIGINT * 2654435761 + salt::BIGINT * 40503) % 2147483647))::DOUBLE
    / 2147483647.0;

-- The two transforms the generator is spent on, both inverse transforms of the uniform.
CREATE OR REPLACE MACRO passes(counter, salt, rate) AS (u01(counter, salt) < rate);
CREATE OR REPLACE MACRO lag_days(counter, salt, mean_days) AS
    CASE WHEN mean_days <= 0 THEN 0.0 ELSE -mean_days * ln(1.0 - u01(counter, salt)) END;

-- The queue inside `demanda`, which is the one funnel above that has a `priorizada` stage and no notion
-- of what prioritising costs.
--
-- Stages 1 to 5 of `demanda` model a demand walking forward with a pass rate and a delay, and that
-- framing cannot answer the question a demand-intake review actually argues about: the team can only
-- work on one thing at a time, so putting this item first puts another item second. A pass rate has no
-- capacity in it. What follows replaces the delay of stage 3 with a server.
--
-- One server, three declared priority classes, exponential service. That is M/G/1 with non-preemptive
-- priority, which is chosen for one reason: it is the largest model of a queue whose mean waiting time
-- is known on paper, per class, for any priority order. Every figure this repository publishes about
-- the queue is checked against that paper.
--
--   rho_k = share_k * arrivals_daily * service_mean_days
--         = 0.15, 0.27, 0.36   and the server is busy 0.78 of the time.
CREATE OR REPLACE TABLE queue_classes AS
SELECT * FROM (VALUES
    ('p1', 1, 'critico',  'Critical incident', 'Incidente critico',   0.10, 1.25, 2.0),
    ('p2', 2, 'padrao',   'Standard request',  'Solicitacao padrao',  0.30, 0.75, 4.0),
    ('p3', 3, 'melhoria', 'Improvement',       'Melhoria',            0.60, 0.50, 6.0)
) AS t(priority, rnk, label, label_en, label_pt, share, service_mean_days, sla_days);

-- The two priority orders compared against first-come-first-served. `reversed` is not a straw man: it
-- is what a team does when it clears the quick items to make the backlog count fall, and because the
-- improvement class is also the cheapest to serve it is the order that minimises the average wait.
CREATE OR REPLACE TABLE queue_disciplines AS
SELECT * FROM (VALUES
    ('priority', 'p1', 1), ('priority', 'p2', 2), ('priority', 'p3', 3),
    ('reversed', 'p1', 3), ('reversed', 'p2', 2), ('reversed', 'p3', 1)
) AS t(discipline, priority, rnk);

-- How long the queue is run, and why it is run for so long.
--
-- 60,000 demands at 1.2 a day is roughly 137 years, which is not a quarter and is not pretending to be
-- one. A waiting time at 78% utilisation has a standard deviation larger than its mean, so the sample
-- needed to pin the mean down to a few percent is far larger than any real operation ever observes.
-- That gap is measured rather than waved at: `queue_measurability` reads the same stream in 180-day
-- slices and reports what a quarterly review could and could not have concluded from one.
CREATE OR REPLACE TABLE queue_params AS
SELECT * FROM (VALUES
    ('queue_arrivals_daily',  1.2, 'Demands arriving per day, Poisson, pooled across the three classes.'),
    ('queue_jobs',        60000.0, 'Demands generated. Chosen for the width of the interval on the closed-form checks, not for realism.'),
    ('queue_sweep_jobs',  20000.0, 'The prefix of that stream the utilisation sweep is run on. The sweep is comparative statics, so it is spent on more utilisations rather than on tighter intervals.'),
    ('queue_slice_days',    180.0, 'The length of the reporting slice a quarterly review would see.')
) AS t(key, value, note);
