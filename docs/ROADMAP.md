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

## Wave 5 — the queue inside `demanda`, and what prioritising cannot do *(complete)*

Waves 1 to 4 are all about a reading being wrong. This one is not about a reading. A pass rate and a delay
contain no capacity, so they cannot represent the fact that makes prioritisation a decision: the team works
on one demand at a time. `sql/90_queue.sql` replaces the delay of a stage with a server — one server, three
declared classes, 0.78 utilisation, M/G/1 with non-preemptive priority — and `sql/95_queue_closed_form.sql`
derives every figure of it on paper.

**Result 1 — the work-weighted total waiting is exactly invariant to the priority order.** Not
approximately, not in expectation, but in every realisation, to twelve decimal places, at every utilisation
swept. The area under the unfinished-work curve over a busy period is the same under any discipline that
never idles while work is waiting, and each demand contributes `service·wait + service²/2` to it; the second
term does not depend on the order. So `sum(service · wait)` cannot either. **Prioritisation is an allocation
of a fixed pool of waiting, not a reduction of it.** All nine per-class means land on Cobham's formula or on
Pollaczek and Khinchine's, the worst deviation being 1.293 standard errors.

**Result 2 — and the metric that would say so is not the one on the dashboard.** The mean wait per demand —
what a service desk reports — rises 18.5% under the order that protects critical demands and falls 24.3%
under the order that abandons them, because the least urgent class is also the most numerous and the
cheapest to serve. The reported KPI therefore rewards the discipline that makes `critico` wait 6.7375 days
instead of 0.6961. Two totals, one invariant and one not, and the operation reports the one that moves for
reasons that are not improvements.

**Result 3 — what prioritising does buy, and the ceiling it cannot pass.** Critical attainment of a two-day
target goes from 0.3752 under first-come-first-served to 0.6295 under absolute priority, bought from
`melhoria`. But 0.7956 is the attainment those same demands would reach *with no queue at all*: the handling
time alone exceeds two days one time in five. A fifth of the target was never reachable by sequencing at any
utilisation under any order, which makes it a target written against a process whose own variation forbids
it — and no amount of prioritisation review will find that out, because prioritisation review does not look
at the service-time distribution.

**Result 4 — waiting is convex in utilisation with elasticity exactly 1/(1 − u).** One percent more demand
buys 4.545% more waiting at the declared 0.78 and ten percent at 0.90. By result 1, no discipline changes a
single row of that sweep. So the only levers on total waiting are the work arriving and the capacity serving
it, and a prioritisation proposal that produces neither has decided who waits without changing how much
waiting there is.

**Result 5 — the one error in this repository that has a sign, and it points the wrong way.** The closed
forms are steady-state limits, and what makes waiting large near capacity is a small number of very long
busy periods — so as the server fills, the number of *independent* observations in a run collapses while the
number of demands does not. At 0.98 one busy period holds 0.2121 of the whole 60,000-demand stream. Read at
three run lengths and three utilisations, all nine readings come out **below** the truth: 0.7048 to 0.9873
at 0.78, and 0.2442 to 0.8422 at 0.98, where even 60,000 demands reads 16% low. Waves 1, 2 and 4 each found
an error with no sign; this one has one, and it understates. **The quantity a capacity review most wants —
how bad does it get when we are nearly full — is the one a finite observation is least able to report, and
its error is in the direction that feels safe.**

**Result 6 — and a quarter is a very short observation.** Cut the unchanging stream into 277 consecutive
180-day slices, 216.6 demands each, nothing different between them, and the slice means run from 0.6441 to
9.3057 days — a factor of 14.4486, attributable to a desk at 0.50 utilisation and a desk at 0.90. The
interval a reviewer would draw around their own mean with sd/√n is ±0.6925 days; the spread the slices
actually show is ±5.8781. The interval is 8.4879 times too narrow. The sample size of a statement about
waiting is not the ticket count but the number of times the queue emptied — a fifth of the ticket count at
0.78 and a fiftieth at 0.98.

**The busy period is the same object three times.** It makes the invariance of result 1 exact; it makes the
interval honest, because busy periods are independent by construction and waits inside one are not; and it
is what made the simulation possible at all, since no ordering of the queue can move the instants at which
the server goes idle — which turns one 60,000-step recursion into thousands of independent ones that run at
once. That last claim is checked rather than assumed: every busy period has to end at the same instant under
every discipline, asserted to machine precision.

One engineering note that is not a defect only because the generator is deterministic. `build` was a phony
target, so `make check` and `make report` each rebuilt the database — three simulations of the same queue per
CI run once wave 5 made a build cost a minute rather than two seconds. The database is now a real file
target. Had any figure depended on wall-clock time or on a library seed, three builds would have meant the
assertions ran against a different database than the one that was printed.

### Defects found and recorded

8. **Standard errors that assumed a queue's waits are independent observations.** The first version of
   `queue_readings` published `sd/sqrt(n)`. A queue's waits are strongly positively correlated: a demand
   that waits a long time arrived behind a pile, and so did the one after it. Treating 60,000 waits as
   60,000 independent draws understates the interval by between 1.482 and 6.362 times, worst for the class
   whose waiting is most caused by other demands. The dangerous part is that **nothing failed**: with the
   naive interval every closed-form comparison still passed, at up to 2.1 standard errors, so the only
   symptom was arithmetic that should have been exact sitting uncomfortably close to a threshold. The fix is
   the standard clustered form over busy periods, which are independent because each starts with an empty
   system. It costs real power and the cost is published: these checks now detect an error of 7.01% to
   20.23%, where the naive interval claimed as little as 2.57% and was wrong to. **A tolerance that is too
   tight fails loudly; an interval that is too narrow passes quietly.**
9. **An assertion that read a stored ratio instead of recomputing it.** `queue_run_length` publishes both a
   reading and a derivation and also a `ratio_to_derivation` column, and the assertions read the column.
   Found by deliberately corrupting a reading in a copy of the database and watching the assertion pass,
   because the stored ratio had not been recomputed. An assertion that reads a derived column is testing
   that the column was copied across, not that the two numbers agree. Every comparison in
   `tests/assert_queue_closed_form.sql` now recomputes from the two published columns. This is the fourth
   time in this repository that an assertion was weaker than it looked, after the harness that never ran the
   file, the rank that was right in order, and the identity nearly asserted backwards.
10. **A generator assertion that tested eleven streams the repository does not use.** `assert_generator.sql`
    checked decile counts, all fifty-five pairs of salts 1 to 11, and lag-one autocorrelation — and the
    repository draws from salts 7, 101, 613 and 977, and now 1301, 1409 and 1511. Defect 1 in this list is
    that the uniformity of one stream says nothing about the independence of two; this is the same sentence
    one level up, and it survived four waves. The twenty-one pairs actually in use are now checked by name:
    the largest absolute correlation is 0.00739. Nothing was wrong with any published figure, which is
    precisely why it lasted — **an assertion about the general case is not an assertion about your case, and
    only the second one is load-bearing.**

## Wave 6 — the class is decided, not known *(complete)*

Wave 5's queue serves the class. No intake desk can, because the class is not written on the demand:
somebody decides it at the counter, with less information than the demand has, before the thing that makes
it urgent is known. `sql/a0_triage.sql` adds a declared confusion matrix between the true class and the
label and re-runs the same queue on the labels; `sql/a5_urgency.sql` derives all of it, and then asks the
question wave 5 left open — given that no order can change the total waiting, which order should it be.

**Result 1 — the label is not the class, and the arithmetic makes that inevitable.** The critical class is
10% of demands; the critical *label* is 16.81% of them, and 4547 of its 10084 tickets came from the critical
class against 5537 from the other two. A small share of two classes that are three and six times larger is
larger than a large share of the class the label names. No indiscipline is required, and no policy statement
would reveal it.

**Result 2 — imperfect triage costs the critical class 49.2% of its waiting, and the cost is a transfer.**
`critico` goes from 0.6961 to 1.0383 days and its two-day attainment from 0.6295 to 0.5941; `padrao` loses
41.0%; `melhoria` *gains* 11.2%, reading 0.8883 of its ideal. Wave 5's invariance survives the relabelling
exactly, the ratio of the two work-weighted totals coming out 1.000000000000 — because relabelling a queue cannot change how much
work is in it. **A triage error is not waste. It is a transfer, and it is paid to whoever the wrong label
sent to the front.** Both halves of the derivation are checked: Cobham on the labels, whose service
distributions are now mixtures, and then the conditional average over labels that gives a true class's wait.
The worst deviation of the six comparisons is 0.867 clustered standard errors.

**Result 3 — the reported metric ranks every possible priority order exactly backwards.** The mean wait per
demand under perfect critical-first priority is 3.0358 days; under this triage desk it is 2.9201, so the
number a service desk publishes *improves* as the triage desk degrades. Worse, enumerate all six orders three
classes can be served in, derive each, and sort by what they cost at the declared urgency: 5.2657, 5.6603,
7.5822, 8.6627, 10.8461, 11.7533 — and the reported mean wait falls monotonically along that list, 3.0691
down to 1.9622. Not correlated with the truth and not uncorrelated: **exactly reversed, on all six.** An
operation optimising its published mean handling time is walking to the worst available order while every
chart improves.

**Result 4 — the two ways to be wrong differ by a factor of 6.6, and only one of them has a floor.** At a
10% error rate, failing to recognise a critical demand costs the critical class 52.8% and escalating a
routine one costs it 8.0%. Escalating *everything* costs 3.8580 times the ideal, which is exactly the
first-come-first-served wait: total over-escalation is no worse than never having sorted the queue at all.
Missing everything costs 5.2470, which is worse. So there is a rate past which sorting is worse than not
sorting, and it is 0.62 under-recognition. **Sorting a queue by a label that is wrong often enough is not a
weak version of sorting it; it is active misdirection.** The work-weighted total is unmoved at all sixteen
swept points and in all six orders.

**Result 5 — the right order is urgency divided by handling time, and the margin is a factor of two.** Given
declared costs, the order minimising weighted waiting ranks by urgency per day of handling: 8.0768, 4.0797,
1.9904, which reproduces the winner of the six. So intuition is right here — by 1.9797 and 2.0497, factors
of two rather than ten, and those margins are ratios of two numbers no escalation policy contains. Sweeping
the critical class's handling time at constant critical workload, critical-first stops being optimal at
2.4512 days, exactly `urgency(critico) × handling(padrao) ÷ urgency(padrao)`, a threshold containing no
arrival rate and no utilisation. **A class blocks the queue in proportion to how long it takes to clear, and
urgency does not scale with that.** The major-incident bridge that holds the team for three days while two
hundred standard requests pile up is what the declared policy asks for, past a threshold the policy never
states.

**Result 6 — and of the two levers, the cheaper one is the one that gets argued about.** On the declared
urgency scale, a realistic mistake in the order costs 1.0749 and the declared triage desk costs 1.1157,
while the critical class feels 1.5632 — roughly five times the excess the account feels. Prioritisation
reviews are about the order. The order is the smaller number.

### Defects found and recorded

11. **I wrote five more of defect 9, one wave after recording it.** Defect 9 was an assertion that read a
    stored ratio column instead of recomputing it from the two published figures. Wave 6's first draft did
    the same thing in five places — the invariance check, the damage signs, the best-order flag, the
    escalation comparison and the two-levers comparison — and the same negative test found it the same way:
    corrupt a published figure in a copy of the database and watch the assertion pass. Recording a defect
    does not prevent it. **The only thing that catches this class is deliberately breaking a figure and
    checking that something fails**, and that step is still manual here, which is the honest statement of
    where this repository's harness ends.
12. **A sentence of arithmetic in the README that was simply wrong.** The first draft explained the top
    label's composition with "8% of 60% is larger than 75% of 10%", which is false — 0.048 against 0.075.
    The conclusion was right for a different reason: two contaminating streams, not one. Every *figure* in
    the prose here is re-derived by `tests/assert_published_figures.sql`, and a sentence that reasons *about*
    figures is not a figure, so nothing could have caught it. The fix was not to correct the sentence but to
    stop reasoning in prose: `triage_purity` now publishes the two counts the sentence was about, 4547 and
    5537, and they are pinned like every other figure. **Prose that does arithmetic is prose that is not
    under test.**

## Wave 7 — what it costs to know *(complete)*

Wave 6 gave the triage desk an error rate and charged nothing for it, which was the last fiction left.
`sql/b0_effort.sql` charges: each look costs the server 0.02 days and reports the true class with
probability 0.70, the label is the mode of `looks` independent looks, and the server doing the looking is
the server doing the work. So accuracy is bought with the only thing the priority order ever had to
allocate, and the confusion matrix stops being declared — it is derived from effort by an exact multinomial
over the ways the votes can land, checked against a draw from the declared generator to a worst deviation of
2.093 standard errors.

**Result 1 — accuracy is not monotone in effort, and the reason is the tie-break.** An even number of looks
can tie. The declared rule sends ties to the more urgent class, which is what a desk under pressure does,
and the consequence is exact: two looks leave `melhoria` at 0.4900 against 0.7000 from one look. The second
look adds no information to that class, it adds a coin flip the tie-break resolves against it. The fourth
look buys the bottom class nothing at all — 0.7840 at three looks and 0.7840 at four, a full look of
capacity spent for exactly zero. **Odd effort helps every class; even effort only helps whichever class the
tie-break favours.**

**Result 2 — the tie-break is a pure transfer, and the mirror is exact.** Under the lenient rule at two
looks the three accuracies are 0.4900 / 0.7000 / 0.9100 — the same figures reversed. The rule creates no
accuracy, it moves it, and at two looks the choice between the rules is worth 7.6569 against 8.5145 on the
declared urgency scale: an 11.2% swing from a line that appears in no triage policy.

**Result 3 — the optimum is one look, and the declared three is worse than none.** One look costs 7.1449
against 7.8212 for no triage at all, a saving of 8.7%. Two looks save 2.1%. Three cost 11.3% *more* than
not triaging, and eight cost 5.3 times more. The declared effort sits past the optimum on purpose: a
parameter tuned to the answer would have hidden the answer. And the effort alone is ruinous before any
sorting enters — 0.16 days of triage per demand takes utilisation from 0.7799 to 0.9730 and multiplies the
same queue's waiting from 2.5868 to 26.3007 days, a factor of ten bought with nothing but looking.

**Result 4 — past a certain effort the critical class itself is harmed.** `critico` waits 1.5789 days at one
look, bottoms out at 1.2124 at five, and returns to 1.5938 at eight — worse than at one look. The class the
triage exists to protect is hurt by the triage, because the triage is standing in its queue.

**Result 5 — how carefully to classify is not a property of the desk.** Sweeping the utilisation carried
before any triage, the effort worth spending is one look from 0.40 to 0.88 and **zero from 0.89 up**: past
that point the effort that would buy a better label costs more waiting than the better label saves. The gain
peaks in the middle, at 0.75 and 8.9%, because below it there is little waiting to reallocate and above it
the looking is ruinous — triage earns its keep in a band, roughly 0.60 to 0.85. And the feasible ceiling
collapses before the optimum does: eight looks are possible at 0.78, five at 0.85, and exactly one at 0.95,
where a second would push utilisation past one and leave the queue with no steady state. **The busier the
desk, the less it can afford to know**, which is the opposite of what happens — when a queue explodes the
first response is a triage meeting.

**And the three waves close on one prescription.** Wave 5: no order reduces the total waiting, it only
decides who bears it. Wave 6: the label the order sorts by is not the class, and getting it wrong is a
transfer. Wave 7: getting it right is paid in the same currency the order was allocating. So at high
utilisation there is one lever and it is capacity — sorting cannot help, classifying makes it worse, and
classifying stops working first.

One simplification is named rather than hidden. The classification time is bundled into the demand's
handling time instead of being charged as its own stage at intake. That is conservative on purpose: real
triage is paid *before* the sorting happens, so it blocks the queue earlier than this model does and costs
more, not less. Charging it properly needs the arrivals into each label to stay Poisson, and they do not
once a classification step sits in front of them — see "Still open".

### Defects found and recorded

13. **The repository tests its documents' language contract and not its own code's.** `assert_documents.sql`
    has checked since wave 1 that every published figure appears in both READMEs in each language's own
    spelling. It checked nothing about the language of the models and assertions — and wave 7's parameter
    block was written in Portuguese and passed the entire suite. Every convention this repository states
    about itself was being enforced except the one it states first: code and comments in English, data in
    whatever language the invented company speaks. Fixed by an assertion over comment lines only, since the
    declared data is deliberately Portuguese, with a word list restricted to function words that cannot
    occur inside an English comment — `com` is excluded for a reason worth recording, because it matches
    inside `github.com`. This is the fourth time a convention in this repository turned out to be enforced
    on everything except itself, after the harness that never ran the file, the assertion that read a stored
    ratio, and the generator assertion that tested streams nobody draws from. **A rule that is stated and
    not compiled is a rule that is already broken somewhere.**

## Wave 8 — the sophistication that loses to one look *(complete)*

Wave 7's effort is a constant. `sql/c0_stopping.sql` makes it a decision: after each look the posterior over
the three classes is recomputed from Bayes with the class shares as the prior, and the desk commits as soon
as the largest posterior crosses a declared threshold. The threshold parameterises the whole family in one
number, because the largest prior share is 0.60 and any threshold at or below it stops before the first
look - so "do not triage" sits inside this policy rather than beside it.

This wave was built to show that the stopping rule wins. It does not, at any utilisation, and the reason is
worth more than the result would have been.

**Result 1 — the effort goes where it is needed, exactly as designed.** At the declared 0.80 threshold the
desk spends 2.0158 times as many looks confirming a critical demand as an improvement - 3.6572 against
1.8143 - and that is correctness rather than carelessness, because the prior is 0.10 against `critico` and
committing to it needs more evidence. The cost is that `critico` is already the slowest class to handle at
1.2381 days and is now also the slowest to classify. **The class that blocks the queue most is the class
most expensive to recognise**, and the two compound.

**Result 2 — the accuracy-maximising rule labels the critical class worse than a single raw look does.** At
its own optimum it recognises `critico` 0.5590 of the time, against 0.7000 from one look that simply reports
what it saw. Bayes shrinks toward the base rate; the base rate says "probably not critical"; and wave 6
established that failing to recognise a critical demand costs 6.6 times what escalating a routine one does.
**Every unit of statistical correctness is paid for in the currency the operation cares about.**

**Result 3 — making the rule cost-aware confirms the diagnosis and gets fewer labels right.** Committing to
the class with the largest posterior *times its declared urgency* beats committing to the largest posterior
at every threshold above the degenerate one - 7.4580 against 7.6623 at the shared optimum - while its
overall label accuracy falls from 0.7872 to 0.7307. Fewer correct labels, less waiting. Both halves are
asserted, because either one alone would be a coincidence.

**Result 4 — and both lose to one fixed look, at every utilisation swept.** The margin runs from 1.0144 at
0.40 utilisation to 1.0569 at 0.82. At 0.40, where looking costs almost nothing, a single raw look still
beats the best stopping rule by 1.4% - which is the sharp form of the finding, because it shows the rule's
disadvantage is not its cost. **It is its objective. Using the prior is what makes it lose, and the prior
does not get cheaper when the server empties.** That is why good triage protocols are written as rule-out
criteria rather than as probability estimates: "escalate if any indicator of severity is present" is the
raw-look rule, and it is worse at labelling and better at not missing, of which only the second is on the
scoreboard.

**Result 5 — the variance of the effort is a real cost and a negligible one here.** The effort is now an
outcome, so it has a spread, and the residual work charges the second moment of the service time. A rule
that looks a variable number of times therefore costs more than one that looks E[K] times exactly. The
mechanism is real and asserted in direction; the magnitude is 1.0015 at worst, a fifth of one percent,
because a look costs 0.02 days against a handling time of 0.6461. It would matter if looking were expensive
relative to doing, and it is named so a reader knows when to care.

**Waves 5 to 8 close on one line.** No order reduces the total waiting; the label the order sorts by is not
the class; getting the label right costs the capacity that makes labels matter; and the sophisticated way of
getting it right is worse than the crude way. Look once, escalate on any indication, and spend the argument
on capacity.

### Defects found and recorded

14. **A stopping rule written twice is two stopping rules.** The first version of the walk evaluated "has the
    posterior crossed the threshold" in two places - once as the condition for expanding a state and once as
    the condition for counting it - on the reasoning that the same expression must give the same answer. The
    probability mass then came out between 0.9 and 1.1 instead of 1, so paths were being both expanded and
    counted, or neither. I did not isolate which of the two evaluations diverged, and that is the point: the
    fix was not to find the discrepancy but to make it impossible, by computing the flag once and carrying
    it as a column so the partition is structural. Worth recording because the symptom was quiet - the
    matrix still had rows, the numbers still looked like probabilities, and only summing the mass showed it.
    **A predicate that decides membership of two complementary sets has to be evaluated once.**
15. **A prediction that came out backwards, recorded as it came out.** I built this wave expecting the
    stopping rule to beat wave 7's constant effort where there is slack, on the reasoning that cheap capacity
    makes accuracy affordable. It never beats it - not at 0.40 utilisation, not anywhere - and the assertion
    in `tests/assert_stopping.sql` now says so explicitly, so that a future change which makes the stopping
    rule win will break the build and force the text to be rewritten rather than quietly contradicting it.
    The reasoning was wrong in a way worth naming: I priced the rule's effort and forgot to price its
    objective. This is the second time in this repository that a wave's expected direction was wrong, after
    wave 4's mechanism that produced no effect, and both times the correct response was to ask why the null
    or reversed result was *right*.

## Wave 9 — stages that are not a partition *(complete)*

Waves 1 to 4 all rest on a shape nobody states: a subject occupies one stage at a time, moves forward, and
stops. That shape is what makes "reached stage k" a well-defined event, "the rate at stage k" a fraction of a
fixed denominator, and the product of the pass rates an upper bound nothing can exceed. `sql/d0_movements.sql`
builds a second event log where subjects skip a stage, fall back to the one before, and come back weeks later
to start again, and `sql/d5_movement_readings.sql` takes the same readings on both logs.

The control is what makes any of it evidence. Entry one attempt one draws salts 7 and 101, which are the salts
`sql/20_events.sql` was built from, so for every subject whose skip coin came up tails the two logs must agree
row for row and day for day. All 127122 such rows do, and `tests/assert_movements.sql` fails on a single
mismatch. Every difference between the logs is a movement and nothing else.

**Result 1 — the ceiling stops being a ceiling.** Wave 1's cheapest diagnostic was that a stage reading above
the product of its own pass rates proves the reading is not a rate. A first entry reaches step three either by
passing step two and then three or by skipping step two and then passing three, so the reach is
[(1-s)*p2 + s]*p3 against a declared ceiling of p2*p3, above it by 1 + s*(1-p2)/p2 for any skip rate at all -
because the skipper was never subject to the coin the ceiling is built from. `venda` reads 0.2911 against a
ceiling of 0.2475, 17.62% above a bound it cannot exceed, on a generator obeying every declared rate to four
standard errors. **The diagnostic fires on a healthy funnel.**

**Result 2 — and it is silent on the funnel that is being bypassed.** `retencao` has the larger derived
breach of the two, 1.1773 against `venda`'s 1.1467, and its windowed cohort reading is 0.1449 against a
ceiling of 0.1496. It reads *below* the ceiling, because the maturity window censors the slow walks the skip
is adding and the two effects cancel. So the diagnostic has both error directions at once. It is not a
diagnostic; it is the question "can this stage be skipped?", and it cannot tell the answer from a broken
metric.

**Result 3 — the denominator is not the number of subjects, and the bias has no sign.** A re-entry adds a row
at the entry stage and a fallback adds one at a middle stage, so counting rows inflates both ends of every
fraction by different factors. `venda` `negociacao` reads 1.0812 times too high by event counting and
`retencao` `em-risco` reads 0.9229 times too low, on the same log. A correction factor would need a sign and
there is not one, which is asserted in both directions so that a change making the bias tidy breaks the build.

**Result 4 — "time to reach a stage" is two numbers.** A fifth of the subjects reaching `venda` `negociacao`
reach it twice, and the mean first touch and mean last touch are 15.29 and 18.04 days. Nothing in the schema
records which one a report meant, and `min` versus `max` inside a `GROUP BY` is the most consequential
undocumented decision in a funnel report.

**Result 5 — the monotone schema cannot hold the log at all.** 174745 rows against 137923 on the same
population, a ratio of 1.2670: 11195 second entries, 29583 rows on the way back up from a fallback, and 29452
subject-stages visited more than once. One row per subject per stage is not a storage choice, it is an
assumption about behaviour.

### Defects found and recorded

16. **A second entry conditioned on the wrong log.** The first version of `sql/d0_movements.sql` decided
    whether a subject comes back by asking how far it got in the *monotone* log of `sql/20_events.sql`,
    because a single recursion cannot both produce the messy answer and consume it. It is a convenient
    substitution and a wrong one: a subject that skips its way to the last stage in the messy log would still
    be sent back, because the monotone log says it failed. The symptom was a closed form disagreeing with the
    simulation on two funnels out of six and agreeing on four, which is exactly the shape of a bug that is
    easy to argue away. The fix was to make the walk a table macro and run it twice, once to produce the first
    entry and once to consume it. **When a derivation needs a quantity the model has not produced yet, the
    model runs twice - it does not borrow a similar quantity from somewhere else.**
17. **A closed form that did not say which population or which horizon.** The derivation
    1 + s*(1-p2)/p2 is about first entries and about the eventual walk. I checked it against the windowed
    cohort reading of all entries, which is wrong in two directions at once: a second entry reaching step
    three pushes the simulation above the formula, and the maturity window - the censoring this entire
    repository is about - pulls it below. The two partly cancelled, which is why the disagreement surfaced on
    two funnels rather than on all six, and why it took a restructure and a rederivation to separate. The
    file now names its population and its horizon in the comment above the table, and publishes the windowed
    figure beside the first-entry one instead of confusing them. **A closed form that does not state its
    population and its horizon is not a closed form, it is a slogan** - and the fact that this one was mine,
    in the wave about unstated assumptions, is the reason it is written down here.

## Wave 10 — the change somebody shipped *(complete)*

Every wave so far measures a funnel. This one measures a decision. `sql/e0_interventions.sql` ships one change
per funnel on a declared day and builds both the world where it was shipped and the world where it was not:
the same subjects, the same coin streams, walked twice. Two of the six raise a pass rate, two move only a
delay and leave the eventual rate exactly alone, one moves both, and one is a placebo that does nothing.

Three things make the word "causal" defensible here. Common random numbers - the changed world reads the same
uniform draw against a larger threshold, so a multiplier at or above one cannot make any subject worse off,
and that is asserted exactly: 107, 76 and 447 subjects gained a conversion and zero lost one. Two exact
controls - subjects arriving before the change reproduce wave 1's log to the day (46734 rows) and so does
every counterfactual (98124 rows), checked row for row rather than in aggregate. And the counterfactual
itself, which is the answer key no operation has: the effect is measured on exactly the population that
received the change, so there is no pre-period, no growth and no mix in the comparison.

**Result 1 — a change that moves only a delay moves no conversion, exactly.** Whether a subject eventually
reaches a stage does not depend on how long it took to get there, so the reach sets of the two worlds are
identical row for row and only the dates differ. The causal lift is 0 at machine precision, not 0 within a
band, and the assertion demands both halves: no conversion moved, and the dates did move. The second half is
what would catch a silent join failure making every zero a zero for the wrong reason.

**Result 2 — the before-and-after window reading gets the launch review backwards.** Thirty days of
conversions before the change against thirty days after it: the change that converted nobody reads +0.3962
and tops the page, while the two changes that genuinely raised conversion by a quarter and by a third read
+0.0218 and +0.0132 - noise, to any reviewer. The true lift is 11.5 and 24.3 times the reported one. The
mechanism is wave 1's applied to a decision: the conversions inside the post-launch window belong mostly to
arrivals from before it, so a rate change is nearly invisible there, while a speed-up pulls conversions that
were already going to happen across the window boundary and every one is counted as new.

**Result 3 — no single horizon separates a rate change from a speed change.** Reading both worlds on the same
cohorts at the same maturity, a pure speed-up decays from +0.6374 at ten days to +0.0047 at sixty while a real
rate lift converges upward toward its true value. At any one horizon the two are indistinguishable. The shape
across horizons is the only signature, which is why a launch read once, at whatever maturity the report
happens to use, cannot answer the question it was commissioned to answer.

**Result 4 — the horizon decides the ranking.** At twenty days the two changes that converted nobody rank
first and second (+0.5385 and +0.4022) and the change that converted the most people ranks below both of them
(+0.1892 against a true +0.3207). At thirty days the page looks respectable and is still wrong: the two real
lifts are in the wrong order and a worthless change is credited with +0.2174.

**Result 5 — the placebo reads exactly zero, and that is a property of the construction rather than a claim
about experiments.** Because both worlds share their coins, a change that does nothing produces two identical
logs and a lift of exactly zero at every horizon. A real A/B test on a placebo reads noise, not zero. The
placebo is here so that a zero on this account has a known meaning, not to suggest that measurement is
noiseless.

### Defects found and recorded

18. **A standard error priced on the wrong scale.** The closed form compares a *ratio* of two correlated
    means, and the first version of the tolerance was four standard errors of the paired *difference* - the
    right idea about the correlation and the wrong units. It flagged retencao's 0.0207 deviation as a failure
    against a 0.0151 band that was measuring a different quantity, and I spent the first minutes looking for a
    bug in the generator rather than in the band. The fix is the delta method with all three terms, covariance
    included: Var(X/Y) = Var(X)/Y^2 + X^2*Var(Y)/Y^4 - 2*X*Cov(X,Y)/Y^3. Dropping the covariance overstates
    the band; forgetting the denominator is a sample understates it. **This is the third time in this
    repository that a standard error was the defect rather than the estimate** - after wave 5's naive sd/root-n
    that understated the interval by up to 6.362 times, and wave 5's own first attempt at clustering - and the
    pattern is worth naming: the estimate gets checked against a closed form and the error bar gets checked
    against nothing.
19. **An undefined ratio ranked first, because nan is not treated as missing.** A funnel whose baseline
    converted nobody inside the shortest horizon produced a lift of zero over zero. DuckDB gives NaN a total
    ordering above every real value - `nan > 0.10` is true and `rank() OVER (ORDER BY x DESC)` puts it first -
    so the ranking crowned an undefined quantity as the best intervention of the six, and the comparison
    assertions agreed with it. The closed-form assertion did fire, because `abs(nan - x) > tol` is also true,
    which is the only reason it was found at all. Fixed by excluding an empty baseline where the table is
    built, and by an assertion over every published lift and tolerance that rejects null, nan and infinity -
    so the filter cannot be removed quietly. **A guard that exists only as a `WHERE` clause in a model is not
    a guard; it is a habit.**

## Wave 11 — the reading that moved because the population moved *(complete)*

Waves 1 to 10 treat a funnel's subjects as one population. They are not: subjects arrive through origins
that convert at different rates, and the share arriving through each origin moves, which makes every
aggregate reading a weighted average whose weights are themselves a time series. `sql/f0_segments.sql`
gives each of wave 1's subjects one of three origins - the arrival counts are untouched, so no earlier
figure moves - and scales the second stage's pass rate by the origin's multiplier. Both the shares and the
multipliers drift across the horizon.

Both comparison periods are halves of the mature horizon, so every cohort in them had the full maturity
window to convert. Wave 1's prescription is already applied to every figure in this wave, which is what
makes the mix attributable: it is a second mechanism, orthogonal to the first, and fixing the first does
nothing about it.

**Result 1 - every origin improved and the aggregate fell.** `direto` went from 0.6430 to 0.7022,
`parceiro` from 0.4551 to 0.4983, `campanha` from 0.2343 to 0.2515; not one declined. The aggregate went
from 0.4890 to 0.4544, a fall six standard errors wide on 12388 and 20836 subjects. The shares are the
reason: `direto` fell from 0.4642 of arrivals to 0.2838 while `campanha` rose from 0.2415 to 0.4126 - the
best origin shrank and the worst grew, and the composition moved further than the rates did.

**Result 2 - the reversal is in the declared parameters, not in the sample.** With the arrival weighting
that wave 1's growth mechanism requires, the declared multipliers are 0.9082, 0.6465 and 0.3272 in the
first period and 0.9252, 0.6595 and 0.3399 in the second, and their weighted average falls from 0.692221
to 0.605715. Three numbers up, their average down, with no sampling anywhere in it. Worth noting for its
own sake: the composition of a period is the arrival-weighted average of its daily shares and not the
share at its midpoint, because arrivals grow - wave 1's mechanism reappearing inside the weights.

**Result 3 - the decomposition is exact, and the familiar one is not.** Weighting each change by the mean
of the two periods,

    d(sum w*p) = sum (w0+w1)/2 * (p1-p0) + sum (p0+p1)/2 * (w1-w0)

collapses algebraically to sum(w1*p1) - sum(w0*p0) with no remainder, so the assertion on it holds at
machine precision rather than within a tolerance. Pooled, the change of -0.034664 splits into +0.040673
inside the origins and -0.075337 between them: the mix is 1.85 times the within-origin effect and points
the other way. The textbook split - rate change at the starting shares, share change at the starting rates
- drops the cross term sum(dw*dp), which is -0.007324 here, a fifth of the whole movement. A decomposition
with a leftover gets the leftover named "interaction" and then interpreted, which is why the exact form is
the one published.

**Result 4 - standardising the weights flips the sign.** Holding the composition at the first period's
shares and reading the second period's rates turns the pooled -0.0347 into +0.0443. Same subjects, same
conversions, same definition of converted. `demanda` is the starkest case: standardised it moved by
+0.0078 and as reported it lost -0.0864, so the entire movement was who arrived.

### Defects found and recorded

20. **An effect that was real, predicted exactly, and unresolvable.** The first version of this wave
    declared a thirty-point share drift and compared two narrow windows at the ends of the horizon. The
    aggregate fall came out at three standard errors - exactly what the arithmetic predicts, and not
    distinguishable from noise at the four-standard-error bar used everywhere else here. The tempting
    response is to loosen the bar for this one result, which would make every other figure in the
    repository less trustworthy to buy one headline. The actual responses were to use the whole mature
    horizon instead of two windows, and then, when that was still not enough, to declare a larger drift -
    written into `sql/00_parameters.sql` with the reason, rather than quietly applied. **The measurement is
    worth more than the fix, and it is kept as a finding: a mix shift large enough to reverse the sign of a
    reported trend sits at the edge of what a few months of data can resolve.** Which is why this reversal
    is argued about in practice rather than demonstrated, and why the decomposition - exact with no sample
    at all - is the artefact to bring to a review.
21. **An assertion placed where its mechanism is not measurable.** The first version measured conversion at
    the *last* stage of each funnel, per funnel, and I was one step from asserting "every origin improved"
    on it. The origin's multiplier acts on the second stage, so reading the last one puts the whole
    funnel's attrition between the mechanism and the measurement: on `venda` the first period had 631
    subjects and about ten conversions per origin, where a declared four percent gain is invisible, and the
    swings that appeared - one origin reading 0.0315 against 0.0566 - were noise that happened to point the
    right way. I caught it by reading the numbers before writing the assertion rather than after. The
    reading moved to the second stage, where the mechanism acts, and the findings that depend on sampling
    moved to the pooled scope, where the cells are large enough to carry them. **An assertion that passes
    because the noise pointed the right way is worse than no assertion, because it will keep passing.**

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
- **No second server.** The queue has one. M/G/1 is where the closed forms are, and the whole point of the
  queue in wave 5 is to be checked against them. Two servers would let the pooling argument in — one shared
  queue against two specialists — which is a real operating decision and needs a model whose answer key is
  simulation rather than algebra. That is a different bargain and should be struck on purpose.
- **No preemption.** A critical demand arriving mid-handling waits for the current one to finish. Preemptive
  priority has its own closed form and a different prescription, and mixing the two would make it unclear
  which result belonged to which.
- **No growth in the queue.** The demand stream of wave 5 is stationary, so wave 1's mechanism is absent
  from it by construction. That is deliberate: a queue whose arrivals grow has both problems at once and
  neither can be attributed. Putting them together is a wave, not a parameter.

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
- **An estimator that survives a short run near capacity.** Wave 5 measures the finite-run bias and shows
  it always reads low. It offers no correction. The honest candidates are a regenerative estimator with a
  stated relaxation criterion, or batch means with the batch length derived from the utilisation rather than
  chosen — and either one needs a claim about how long is long enough, which is exactly the claim the result
  says a finite observation cannot support. Saying which is worth the assumption is the next argument.
- **Abandonment, and the difference between late and never.** The queue in wave 5 loses nobody: every demand
  waits as long as it takes. A real intake desk has demands that are withdrawn, escalated out of the queue,
  or quietly abandoned, and each of those censors the *longest* waits — which would make the reading of a
  queue's waiting time informatively censored in exactly the sense wave 4 built. `entregue` and `resolvido`
  are still binary too, and an operation distinguishes delivered-on-time from delivered-late from abandoned.
- **A service target read off the tickets that closed.** Wave 5 reports attainment over every demand. A real
  dashboard reports it over the ones that finished inside the window, which is wave 1's reading applied to a
  queue — and under a priority order the demands still waiting are systematically the low-priority ones, so
  the censoring is created by the policy rather than by the calendar. The queue here is stationary, which is
  why that effect is small enough not to be worth publishing yet; it is not small in a growing one.
- **A triage matrix somebody could estimate.** Wave 6's confusion matrix is declared, and an intake desk
  cannot see its own. Estimating it needs the true class to be revealed later — which for an incident it
  sometimes is, once the thing has been worked — so the honest object is a delayed, partially observed label
  and a correction built on it. Whether the later revelation is representative of the demands whose class is
  never revealed is the same question wave 4 asked about censoring, and it has the same uncomfortable answer.
- **Classification charged as its own stage rather than bundled into the handling.** Wave 7 adds the triage
  time to each demand's service, which is conservative but not what happens: the looking is done at intake,
  before the label exists, so it blocks the queue earlier and costs more. Charging it properly makes the
  arrivals into each label non-Poisson, which is exactly the assumption Cobham's formula needs, so it wants
  either a simulation as the answer key or a derivation this file does not have.
- **A stopping rule whose objective is the queue rather than the label.** Wave 8 compares an
  accuracy-maximising rule with one weighted by declared urgency, and the second is better. Neither is
  optimal: the truly cost-optimal rule would stop when the expected cost of another look exceeds the
  expected cost of committing now, and both of those depend on the waiting the policy itself produces. That
  is a fixed point, and solving it needs an iteration this repository has no room for in pure SQL.
- **A look whose accuracy depends on the demand.** Every look here is right with the same probability
  whatever it is looking at. Real ambiguity is a property of the demand, not of the observer, so some
  demands are genuinely undecidable and more looking cannot settle them - which changes the stopping rule
  from "look until sure" to "look until sure or until sure it will not become clear".
- **Escalation as a repeated decision.** A demand's label is set once and never revisited. Real operations
  re-triage: things get escalated after they have waited, which couples the label to the queue state and
  makes the whole system a feedback loop rather than a sorting.
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
