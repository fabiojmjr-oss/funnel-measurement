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

-- The triage decision, which wave 5 did not have.
--
-- In wave 5 the class is a property of the demand and the queue serves it perfectly. No intake desk works
-- that way. Somebody classifies the demand on partial information, at the moment it arrives, before the
-- thing that makes it urgent is known - and the queue then serves the **label**, not the class.
--
-- So there are two classes per demand from here on: the one that determines how much its delay costs, and
-- the one written on the ticket. The matrix below is the second given the first. The two error directions
-- are not the same mistake and the wave is about how differently they behave:
--
--   * under-recognition - a genuinely critical demand that arrives looking routine and goes to the bottom
--     of the queue. Rare, and catastrophic for that demand.
--   * over-escalation - a routine demand labelled critical because whoever raised it said it was urgent.
--     Common, and it does not hurt that demand at all. It raises the utilisation of the top class, which
--     is the only thing protecting the genuinely critical ones.
--
-- The rows are read as: of the demands whose true class is `true_priority`, this share is labelled
-- `assigned_priority`. Each row sums to one, which tests/assert_triage.sql checks rather than assumes.
CREATE OR REPLACE TABLE queue_triage AS
SELECT * FROM (VALUES
    ('p1', 'p1', 0.75), ('p1', 'p2', 0.20), ('p1', 'p3', 0.05),
    ('p2', 'p1', 0.15), ('p2', 'p2', 0.75), ('p2', 'p3', 0.10),
    ('p3', 'p1', 0.08), ('p3', 'p2', 0.22), ('p3', 'p3', 0.70)
) AS t(true_priority, assigned_priority, probability);

-- What a day of delay costs, per class, as an exchange rate rather than as money.
--
-- Wave 5 established that the work-weighted total waiting cannot be moved by any ordering, which means
-- the only thing an ordering can do is decide who waits. Deciding *well* requires saying what waiting
-- costs, and there is no honest way to avoid that: a priority order is a statement about relative cost
-- whether or not anybody writes the numbers down.
--
-- The weight below is dimensionless on purpose: it is how many days of delay on a `melhoria` one day of
-- delay on this class is worth. No currency appears anywhere in this repository and none is needed - the
-- rule that minimises weighted waiting depends only on ratios.
--
-- The declared 10 : 3 : 1 is deliberately conventional. The finding of sql/a5_urgency.sql is that the
-- order these weights imply is **not** the order they are written in, and that the correction has nothing
-- to do with urgency.
CREATE OR REPLACE TABLE queue_urgency AS
SELECT * FROM (VALUES
    ('p1', 10.0), ('p2', 3.0), ('p3', 1.0)
) AS t(priority, urgency_weight);

-- The third discipline: serve the label the triage desk wrote, under the same critical-first ranking.
-- Wave 5 claimed that adding a discipline was a row in this file and no change to the recursion. This is
-- that claim being tested - the ranking is identical to `priority`, and only the labelling differs.
CREATE OR REPLACE TABLE queue_label_sources AS
SELECT * FROM (VALUES
    ('priority', 'true'),
    ('reversed', 'true'),
    ('triaged',  'assigned')
) AS t(discipline, label_source);

-- What triage costs, which in wave 6 was free.
--
-- Wave 6's confusion matrix is declared and costless: the label comes out wrong, and nothing was spent
-- producing it. No intake desk works that way. Classifying takes looking, and looking consumes exactly the
-- resource the priority order exists to allocate - the server's capacity. A desk that spends half an hour
-- classifying every demand raises the utilisation it exists to manage.
--
-- The accuracy model is discrete on purpose. Each look reports the true class with probability
-- `look_accuracy` and, when it errs, picks uniformly between the other two. The label is the mode of
-- `looks` independent looks. That gives a confusion matrix which falls out of an exact multinomial, with no
-- special function and no approximation to verify - which matters in a repository whose rule is to derive
-- before simulating.
--
-- It also brings a consequence no triage policy writes down: an even number of looks produces ties, and a
-- tie has to be broken by rule. Both rules are declared below, because the tie-break is a free lever and
-- wave 7 measures what it transfers.
--
-- The classification time is bundled into the demand's handling time rather than charged as a separate
-- stage at intake. That is the conservative simplification and the reason is worth stating: real triage is
-- paid *before* the sorting happens, so it blocks the queue earlier than this model does and therefore
-- costs more, not less. Charging it as its own stage needs the arrivals into each label to stay Poisson,
-- which they do not once a classification step sits in front of them - see "Still open" in docs/ROADMAP.md.
CREATE OR REPLACE TABLE queue_effort AS
SELECT * FROM (VALUES
    ('look_days',      0.02, 'Server time each look consumes, in days. About half an hour.'),
    ('look_accuracy',  0.70, 'Probability that one look on its own reports the true class.'),
    ('declared_looks', 3.00, 'Triage effort of the base scenario. Deliberately past the optimum: a declared parameter tuned to the answer would hide the answer.'),
    ('max_looks',      8.00, 'Largest effort swept. Beyond it the utilisation passes one and the queue has no steady state.')
) AS t(key, value, note);

-- The two tie-break rules. `urgent` sends a tie to the more urgent class, which is what a desk under
-- pressure does; `lenient` sends it to the less urgent one.
CREATE OR REPLACE TABLE queue_tie_breaks AS
SELECT * FROM (VALUES
    ('urgent',  'A tie goes to the lower rank, that is, to the more urgent class.'),
    ('lenient', 'A tie goes to the higher rank, that is, to the less urgent class.')
) AS t(tie_break, note);

-- The desk that decides how hard to look, demand by demand.
--
-- Wave 7's effort is a constant: every demand gets the same number of looks, whether the first look settled
-- the matter or left it wide open. No desk works that way either. A real one stops early on the obvious
-- ones and keeps looking at the ambiguous ones, which makes triage a sequential decision with a stopping
-- rule - and the stopping rule is where the remaining gain is.
--
-- The rule declared here is the natural one. After each look the posterior over the three classes follows
-- from Bayes with the class shares as the prior and `look_accuracy` as the likelihood; the desk stops when
-- the largest posterior crosses `stop_threshold`, and otherwise looks again until the budget runs out.
--
-- The threshold parameterises the whole range in one number, which the integer effort of wave 7 could not.
-- The prior's largest share is 0.60, so any threshold at or below it stops before the first look and labels
-- every demand alike - that is, "do not triage" is not a separate policy here, it is the low end of this
-- one.
CREATE OR REPLACE TABLE queue_stopping AS
SELECT * FROM (VALUES
    ('look_budget',     8.00, 'Most looks the desk may take on one demand before it has to commit.'),
    ('declared_threshold', 0.80, 'Posterior the desk waits for before committing, in the base scenario.')
) AS t(key, value, note);

CREATE OR REPLACE TABLE queue_thresholds AS
SELECT * FROM (VALUES
    (0.60), (0.65), (0.70), (0.75), (0.80), (0.85), (0.90), (0.95), (0.99)
) AS t(stop_threshold);

-- The three things a real subject does that a monotone staircase cannot represent.
--
-- Waves 1 to 4 model a funnel as a walk forward, one step at a time, and a subject that fails a step simply
-- has no row for it or for anything after. That is the shape of the arithmetic, not the shape of the
-- process. Real subjects skip stages, go backwards, and come back months later - and a model that drops all
-- three does not report that it dropped them.
--
--   * `skip_rate` - the share of subjects that bypass step two and arrive at step three directly. A lead
--     that is obviously qualified is not qualified again; a demand that is obviously critical is not
--     triaged. The skipper is still subject to step three's own coin.
--   * `fallback_rate` - the share of subjects that, on reaching a step at or beyond the third, return to
--     the one before it and then have to make their way forward again. A deal in negotiation goes back to
--     proposal; a resolved ticket is reopened.
--   * `reentry_rate` - the share of subjects that, having failed to finish, start the funnel again from
--     step one after a delay. A lost deal comes back next quarter; a churned customer returns.
--
-- Each deviation happens at most once per subject. That is a declared bound rather than a realistic one,
-- and it is there because an unbounded version has no closed form at step three - and step three is where
-- this wave's finding has to be checked against arithmetic rather than against itself.
CREATE OR REPLACE TABLE movements AS
SELECT * FROM (VALUES
    ('venda',       0.12, 0.18, 0.25),
    ('ativacao',    0.08, 0.10, 0.15),
    ('retencao',    0.05, 0.22, 0.40),
    ('resgate',     0.20, 0.08, 0.35),
    ('atendimento', 0.15, 0.30, 0.10),
    ('demanda',     0.10, 0.14, 0.20)
) AS t(funnel, skip_rate, fallback_rate, reentry_rate);

CREATE OR REPLACE TABLE movement_params AS
SELECT * FROM (VALUES
    ('reentry_delay_days', 45.0, 'Mean wait before a failed subject starts again, drawn from the declared exponential.'),
    ('fallback_delay_days', 6.0, 'Mean wait on the way back to the previous stage, and again on the way forward.')
) AS t(key, value, note);

-- The streams the messy walk draws from.
--
-- A subject can walk its funnel up to twice - once on its first entry and once if it comes back - and
-- within each entry it can make up to two attempts at the stages beyond a fallback. Each of those four
-- combinations needs its own pair of streams, or a subject that goes back and tries again meets the coin
-- that already decided its fate and the second attempt is not an attempt at all.
--
-- Declaring them here rather than deriving them inline is the same discipline as every other salt in this
-- file: tests/assert_generator.sql checks that the streams this repository actually draws from are
-- independent, and it can only check the ones it can see.
CREATE OR REPLACE TABLE walk_salts AS
SELECT * FROM (VALUES
    (1, 1,    7,  101), (1, 2, 2221, 2251),
    (2, 1, 2311, 2347), (2, 2, 3371, 3373)
) AS t(entry, attempt, pass_salt, lag_salt);
