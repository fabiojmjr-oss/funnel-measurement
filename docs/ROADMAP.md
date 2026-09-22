# Roadmap

What is built, what is deliberately absent, what is still open, and the defects found on the way. In
English, like the rest of the code; the findings themselves are in both languages in the two READMEs.

## Wave 1 — the reading, not the funnel *(complete)*

The question this repository opens with is not "how do these funnels perform". It is "what is a funnel
conversion rate a rate of", and the answer turns out to be: three different things, depending on which of
the four readings somebody ran.

- `sql/00_parameters.sql` — six funnels, twenty-eight stages, every pass rate, every mean delay, every
  arrival growth, and the generator written in arithmetic.
- `sql/10_subjects.sql` — arrivals compounded per funnel per day. 47,317 subjects over 180 days.
- `sql/20_events.sql` — a recursive walk of the stages. A subject that fails a step simply has no row
  for it or for anything after it, which is the shape a real event table has and the reason a funnel
  cannot be read by counting rows per stage.
- `sql/30_readings.sql` — the window reading, the all-time reading, the cohort reading and the declared
  eventual ceiling, side by side, plus the distortion between two of them.
- `sql/40_closed_form.sql` — both readings derived on paper at step two, where the algebra closes, and
  the two mechanisms isolated by sweeping one parameter at a time.
- `tests/` — seven assertion files, the last of which reads the repository's own documents. An
  assertion is a query returning the rows that break it, so the harness is `make` and nothing else.

**Result 1 — the error has no sign.** Across the six funnels the window reading divided by the cohort
reading runs from 0.9218 to 1.9826. A manager cannot carry a mental correction because the correction
changes sign with the growth of their own pipeline.

**Result 2 — the window reading is a steady-state estimator of the wrong quantity.** With arrivals flat
it converges *exactly* on the declared eventual rate, for any delay, to nine decimal places. It is not
noisy and it is not biased about that quantity. It is answering "what share eventually converts" when the
question asked was "what share converts inside the month I am measured on", and the gap between those two
questions is the delay: 0.4500 against 0.2845 at a thirty-day mean delay.

**Result 3 — growth breaks even that.** With the delay fixed, the window reading falls monotonically in
arrival growth across all sixty-one points of the sweep and crosses the cohort reading exactly at zero
growth. The same funnel with the same behaviour reads 1.1651 times as high at −3% a day as at +3%.

**Result 4 — six stages read above a rate they cannot exceed**, four of them by more than sampling noise
allows, all on the shrinking funnel, the worst at 1.4161 times its own ceiling. A conversion rate larger
than the maximum achievable conversion rate is the cheapest available proof that the reading is not a
rate, and it costs one query.

### Defects found and recorded

1. **A generator that passed the obvious test and was badly broken.** The first version of `u01` was
   three Lehmer steps on `index * 48271 + salt * 7919`. Its mean sat on 0.49999 and its range filled the
   unit interval — the two things anybody checks. Two streams on the same index correlated at **−0.42**,
   because a purely multiplicative generator turns an additive difference between salts into a fixed
   offset, and every pass/delay pair in this repository is two streams on the same index. Found by
   measuring the thing the repository actually needs rather than the thing that is easy to measure:
   **the uniformity of one stream says nothing about the independence of two.** The replacement
   interleaves a shift-and-xor with the multiply and is asserted on decile counts, on all fifty-five
   pairs of eleven streams, and on lag-one autocorrelation.
2. **A population identity asserted on a sample.** A cohort rate is a truncation of the eventual rate, so
   it cannot exceed it — in expectation. The first version of that assertion left out the last two words
   and failed on six stages whose delays are so short that the truncation removes nothing measurable; the
   sample then straddles the ceiling by less than a standard error. The fix is a tolerance of four
   standard errors computed from the cohort denominator, which is the same correction the closed-form
   assertion already used. Worth recording because the assertion was *more* strict than the truth and
   would have been "fixed" by loosening it to an arbitrary epsilon instead of to a derived one.

3. **A harness that reported green for a file it never executed.** `make check` ran each assertion and
   treated empty output as a pass. An assertion with a syntax error prints nothing to stdout, so the
   third file added here - the one that reads the repository's own documents - failed to parse and was
   reported as `ok`. The hole was visible only because DuckDB printed the parser error to stderr and it
   landed in the middle of the run's output; with stderr redirected it would have been silent.
   **Zero rows is a pass only if the query ran**, and the target now checks the exit status as well as
   the output. Worth recording as the most dangerous of the three: the other two were wrong answers,
   this one was a green build over an assertion that did not exist.

## Wave 2 — the same censoring, in the time dimension *(complete)*

Wave 1 read the rate. The other half of a funnel review is the duration, and the subjects missing from
that average are exactly the slow ones. `sql/50_velocity.sql` adds four time readings beside wave 1's
four rate readings, both closed forms, and the sweep that isolates the mechanism.

**Result 1 — the naive mean time is fast everywhere, between 0.818 and 1.002 of the truth.** The most
distorted funnel is the fastest-growing one, which is the same ordering wave 1 found and the same cause.

**Result 2 — the ranking inverts at the top.** `retencao` is the slowest funnel in the account, at a
declared 30.0 days, and reads as the second slowest at 26.82. `resgate` is second at 29.0 and reads as
the slowest at 29.07. The cause is that `resgate`'s arrivals are *shrinking*, so its observed conversions
come almost entirely from old cohorts and its reading is censored by almost nothing — 1.002 of the truth.
**The funnel measured most honestly is the one whose demand is dying**, which is a sentence no operating
review has ever said out loud.

**Result 3 — unlike the rate, the time reading has no fixed point.** Wave 1's dashboard rate is exactly
the eventual rate when arrivals are flat. Sweeping arrivals against a twenty-day delay, the time reading
is 0.9857 of the truth at −3% a day, **0.8756 at flat arrivals**, and 0.6257 at +3%. There is no growth
rate at which it is right, because the young cohorts exist whether or not they are growing.

**Result 4 — the assumption-free measure is not a duration.** The restricted mean,
`mean(min(time, W))` over every subject of a mature cohort, needs nothing assumed about the unconverted
and has the closed form `(1 − p)·W + p·m·(1 − e^(−W/m))`. It is also, by construction, a blend of duration
and completion: `atendimento` is 5.77 times faster than `retencao` and its restricted mean is only 1.61
times lower, because 52.7% of its subjects never reach the last stage and are counted at the window's
edge. So the honest report is the restricted mean **beside** wave 1's cohort rate — a pair, because each
one alone can be moved by the other.

Both time readings are verified against the algebra at step two, where a single exponential closes. The
largest of the twelve deviations is 1.11 standard errors, and the tolerance is four of them computed from
the simulation's own spread rather than from a binomial, because these are means and not proportions.

### Defects found and recorded

4. **A window function ranked the rows the query had not filtered yet.** `speed_ranking` computed
   `rank() OVER (ORDER BY declared_mean DESC)` in the same query as the `QUALIFY` that picks each funnel's
   last stage. A window function is evaluated **before** `QUALIFY`, so the ranks were computed over all
   twenty-eight stages and came out 1, 2, 3, 5, 8, 15 for six funnels. Visible only because the numbers
   were printed and read: every rank was still in the right *order*, so any assertion about the ordering
   would have passed. Fixed by selecting the last-stage rows in a CTE and ranking that. The class is worth
   naming — **an off-by-something that preserves the property you would have tested** is the kind that
   survives a test suite, and the only thing that caught it was looking at the output.

## Wave 3 — the estimator that needs neither the discard nor the assumption *(complete)*

Waves 1 and 2 diagnosed the same censoring twice and prescribed the same expensive fix: read only cohorts
old enough to have finished. `sql/60_survival.sql` replaces it with the standard answer, which is standard
because it throws nothing away.

**Result 1 — the cohort reading discards 29.8% of the subjects**, 14,093 of 47,317, and the share grows
with the arrival growth: it costs most data exactly where the business is moving fastest.

**Result 2 — the product-limit estimator gives the same answer with a tighter interval, on all
twenty-two stages.** The ratio of standard errors runs from 0.7698 to 0.9809 and never reaches one, which
is 1.24 times the data on average and 1.688 times on `demanda`, the fastest-growing funnel and therefore
the one whose young cohorts the cohort reading was refusing to look at. Three closed forms are verified at
step two: the incidence `p·(1 − e^(−W/m))` within 1.05 standard errors, the plateau against `p`, and the
half-life against `m·ln 2` to within 2.82%.

**Result 3 — the median time to a stage usually does not exist.** It needs more than half the subjects to
get there, and fourteen of the twenty-two stages here never do. `resgate` abordado misses having one by
eight thousandths of a conversion rate. A report quoting a median for a stage 7% of subjects reach has
computed the median among the ones who made it, which is a different population every month. The quantity
that is always defined is the half-life — the day by which half of the *eventual* conversions have
happened — whose closed form `m·ln 2` contains no `p`, making it the only speed measure in this repository
that a change in completion cannot move.

**And the assumption is stated rather than buried.** The estimator needs censoring to be unrelated to when
a subject would have converted. Here it is, because the only thing censoring anybody is the calendar. In a
real funnel it frequently is not — archived records, a "lost" flag on stale cases, a pipeline review that
closes what looks dead — and each of those censors the slow subjects *because* they are slow, which is the
one failure that cannot be detected from inside the estimator.

### Defects found and recorded

5. **A survival curve computed on buckets instead of on times.** The first version floored every follow-up
   to a day, which is what a reporting table looks like and is wrong for a reason the buckets hide: a
   subject that arrived today is censored at zero days of follow-up and lands in the day-zero risk set
   beside that day's events. It has had no exposure, so it cannot have an event, and it dilutes the
   day-zero hazard and every factor of the product after it. On `atendimento`, whose delay is a fifth of a
   day and whose events therefore almost all fall on day zero, the estimate came out 0.0059 below a closed
   form it should land on — 0.9523 against 0.9582. Caught by having the closed form to land on: the curve
   was monotone, the risk set shrank, every structural assertion passed, and the only thing that failed was
   the comparison with arithmetic done separately. **A plausible number that satisfies every property you
   thought to test is what a derivation is for.**

## Wave 4 — the assumption wave 3 makes, broken on purpose *(complete)*

Wave 3 ended on a caveat and named it the next step. Breaking it took two moves, and the first one is a
finding about the first three waves.

**Result 1 — an exponential delay cannot be broken by archiving.** Under one exponential a subject open for
twenty days is exactly as likely to convert tomorrow as one that opened this morning, so removing a share
of the slow ones removes nothing the estimator needed. The first version of this wave archived every stale
record with one probability and produced no bias, correctly: a censoring rate that depends only on elapsed
time is what the method allows. So the exponential had to go before the assumption could be broken.

**Result 2 — spread alone makes the measured speed faster, at a mean that has not moved.** Two declared
classes, 30% slow at 2.5× and 70% fast at 0.357143×, calibrated so the mean multiplier is exactly 1. The
estimator stays right on the mixture, within 1.38 standard errors of the two-exponential closed form. But
the *observed* mean delay falls — 17.2008 days to 14.5152 on `retencao`, a ratio of 0.8439 — because the
extra spread pushes more of the slow class past the horizon. **Wave 2 assumed one exponential and therefore
understated its own finding by up to 15.6%.**

**Result 3 — the review that breaks the estimator is judgement, not a stopwatch.** Somebody opens the
record, asks the account manager and closes what is genuinely dead, and that judgement correlates with the
class. At the declared 21-day window the review closes 9,541 records, 75.55% of them slow against 29.87% of
the population: 2.529 times more likely to close a slow record. Nothing in the data records the class,
which is why the resulting bias cannot be detected from inside it.

**Result 4 — and the bias has no sign.** `retencao` reads 1.0450 of the truth at a three-day window and
`venda` reads 0.9372, from the same review at the same window. Archiving hides conversions that would have
happened, which pushes the estimate down; it also removes never-converters from the risk set early, which
pushes the estimated hazard up. Which wins depends on the pass rate *and* on the slow class's delay against
the window. Across the sweep the ratio runs 0.9372 to 1.0450, seven points above one and twenty-three below,
`resgate` changes sign within its own sweep, and the magnitude is not monotone either — `retencao` reads
1.0036 at fourteen days and 1.0082 at twenty-one. **That is the third time this repository has found an
error with no sign**, after wave 1's rate and wave 2's inverted ranking, and the three are the same
structural fact seen from three sides: a reading whose error is a function of two parameters cannot be
corrected by knowing one of them.

**Result 5 — but there is an exact condition.** All eighteen sweep points whose review window is at or
beyond the reporting horizon are unbiased to machine precision, because a review that removes nobody before
day thirty cannot touch an estimate made at day thirty. Inside the horizon only six of thirty-six are. The
prescription needs no statistics: compare how long a record sits before the review closes it against how
many days the conversion report covers, two numbers that currently live in different documents.

### Defects found and recorded

6. **A mechanism that produced no effect, because the model it attacked was immune.** The first archiving
   rule closed every stale record with a single probability and moved nothing. It was not a bug in the SQL -
   the query was right - it was a design that could not work, and the reason is the memorylessness of the
   exponential every earlier wave had assumed. Worth recording because of what nearly happened next: the
   obvious response to "the effect is not there" is to turn the parameter up, and a 0.9 archiving
   probability would still have produced nothing while looking like a serious test of the assumption. The
   fix was not a bigger parameter but a different model, and the thing that identified it was asking why the
   null result was a *correct* null result.
7. **An assertion I nearly wrote backwards.** Having calibrated the mixture to preserve the mean delay, the
   natural check is that the observed mean is unchanged. It is not - it falls by up to 16% - and asserting
   it would have failed for the right reason and been "fixed" by loosening the tolerance until it passed.
   The identity that holds is on the **declared** parameters: the shares sum to one and the mean multiplier
   is exactly one, both asserted at 1e-9 and 1e-6. The drop in the observed mean is a published result
   rather than a tolerance. This is the second time in this repository that a population identity was nearly
   asserted on a sample, and both times the sample was right and the assertion was wrong.

## What is deliberately not here

- **No second language.** The whole repository is SQL plus a Makefile. An assertion returning the rows
  that break it needs no test framework, and a model written as a table needs no ORM. The cost is that
  anything genuinely iterative — a fitted curve, an optimisation — cannot live here, and when one is
  needed it will be a separate tool rather than a rewrite of this one.
- **No dashboard.** The output is tables and a decision. A chart of the window reading would be a chart
  of the thing this repository exists to argue against.
- **No fitted parameters.** Every rate and delay is declared. Fitting them to anything would make the
  answer key unavailable, and the answer key is the only reason the findings can be stated at all.
- **No real conversion benchmarks.** There are no market figures here, quoted or implied. A rate in these
  files is a property of these files.
- **No money.** Stages are counted in subjects and days. A revenue-weighted funnel is a different and
  bigger claim, and it would let a mix shift masquerade as a rate change — which is worth building on
  purpose rather than acquiring by accident.
- **No attribution.** Nothing here decides which touch caused which transition. Attribution is a separate
  argument and mixing it in would make every finding above contestable on the wrong grounds.

## Still open

- **A correction for informative censoring, rather than a diagnosis of it.** Wave 4 measures the damage and
  gives the one condition under which there is none. It offers no estimator that survives a short review
  window, and the honest options - a sensitivity analysis over the unobserved class, or an inverse-probability
  weighting on whatever the reviewer *did* see - both need something the data does not contain. Saying which
  of them is worth the assumption is the next argument.
- **The class as something an analyst could estimate.** The two classes here are declared and unobservable.
  A real account has features that correlate with them - channel, size, who owns the record - and whether
  those features recover enough of the class to make the censoring ignorable is an empirical question this
  file cannot answer and a real one can.
- **A confidence band rather than a standard error.** Wave 3 reports Greenwood's standard error at the
  window. A simultaneous band over the whole curve is a different and larger quantity, and quoting the
  pointwise one as though it covered the curve is the next mistake in this family.
- **Stages that are not a partition.** Everybody here walks forward one step at a time. Real subjects
  skip stages, go backwards, and re-enter months later. A funnel drawn as a monotone staircase drops all
  three silently, and the count of dropped rows is a number no funnel report contains.
- **Priority, and the queue inside `demanda`.** The demand funnel has a `priorizada` stage and no notion
  of a queue discipline: nothing here models what happens to the items that are not prioritised. That is
  where a prioritisation funnel earns or loses its argument, and it needs a service-rate model rather
  than a pass rate.
- **An SLA, and the difference between late and never.** `entregue` and `resolvido` are binary here. An
  operation distinguishes delivered-on-time from delivered-late from abandoned, and the three have
  different owners.
- **Retention as a survival curve rather than a funnel.** `retencao` is modelled as four stages, which is
  a convenience. Renewal is recurring, so the honest object is a survival function with repeated events,
  and the funnel framing is what makes a churned customer look identical to one who has not renewed yet.
- **Winback eligibility as a decision rather than a rate.** `resgate` passes 61% of lost customers to
  `elegivel` by a coin. A real winback programme *chooses*, and the choice is where its return comes
  from — which makes it a targeting problem sitting on top of the funnel.
- **The funnels a mature company has and this file does not.** Dunning and credit recovery, hiring, and
  incident-to-post-mortem are all stage processes with the same reading problem, and each has a wrinkle
  the six here do not: a legal clock, an external market, and a severity that changes the stage list.
- **More than one cohort dimension.** Everything is cohorted by arrival day. Channel, segment and region
  are the cuts a real funnel review argues about, and a mix shift across them produces a fifth reading
  that moves without anybody's behaviour changing.
