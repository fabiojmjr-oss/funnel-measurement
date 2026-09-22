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

- **Velocity, and the survivorship in it.** The mean time to a stage, computed over the subjects who
  reached it, is biased downward by exactly the subjects who have not reached it yet — the same censoring
  that produces wave 1's findings, in the time dimension instead of the rate dimension. It is the next
  wave and it is cheap, because the event log already carries `age_at_stage`.
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
