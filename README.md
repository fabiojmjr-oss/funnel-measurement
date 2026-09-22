# The funnel every company draws, and the arithmetic that says it is not a rate

*[Português](README.pt-BR.md)*

**A funnel conversion rate is almost always computed by dividing two numbers that belong to different
people.** Count how many entered stage one this month, count how many reached stage five this month,
divide. Whoever reached stage five this month entered the funnel two months ago. The ratio is not a
conversion rate of anything — it is the shape of the arrivals divided by itself at a lag.

This repository builds six funnels a mature company runs, reads each of them four ways, and shows that
the reading on the dashboard is **not biased in a knowable direction**. It is the sum of two errors with
opposite signs, and which one wins depends on whether demand is rising or falling and on how long the
funnel takes. On one of the six it reads **1.98 times** the real conversion rate. On another it reads
**0.92 times** it. Same engine, same behaviour, no bug.

Everything here is **SQL**. Nine model files, eleven assertion files, a Makefile that decides the order, and
no second language: an assertion is a query that returns the rows which break it, so zero rows is a
pass and the harness needs no test framework. Every number in the documents below is re-derived by
`tests/assert_published_figures.sql`, so a change that moves a published figure breaks the build
instead of leaving the text quietly wrong.

No employer, client, customer or vendor data appears anywhere — see [`DISCLAIMER.md`](DISCLAIMER.md).

## The six funnels

Declared in [`sql/00_parameters.sql`](sql/00_parameters.sql), every number of them. **47,317** subjects
over 180 days produce **144,858** stage events, of which 137,923 have happened by the day the report is
run.

| Funnel | Stages | Arrivals |
| --- | --- | --- |
| `venda` — sales | lead → qualificado → proposta → negociacao → fechado | growing 1.2%/day |
| `ativacao` — activation | contratado → configurado → primeiro-uso → uso-recorrente | growing 0.8%/day |
| `retencao` — retention | ativo → em-risco → contato-feito → renovado | flat |
| `resgate` — winback | perdido → elegivel → abordado → respondeu → reativado | shrinking 0.9%/day |
| `atendimento` — service | aberto → triado → em-atendimento → resolvido → confirmado | growing 0.3%/day |
| `demanda` — demand intake | registrada → classificada → priorizada → em-execucao → entregue | growing 2.0%/day |

The arrival growth is not decoration. It is the parameter that decides how wrong the dashboard is, and
it is the one parameter a funnel report never mentions.

## The finding, in one table

Each funnel at its last stage. `dashboard` is the window reading described above; `cohort` is the share
of a cohort old enough to have had its chance; `ceiling` is the declared eventual rate, which is the
most the funnel can ever deliver.

| Funnel | Arrivals | `dashboard` | `cohort` | `ceiling` | dashboard ÷ cohort |
| --- | --- | --- | --- | --- | --- |
| `resgate` | **−0.9%/day** | 0.0743 | **0.0375** | 0.0602 | **1.9826** |
| `retencao` | flat | 0.1080 | 0.0636 | 0.1107 | **1.6988** |
| `atendimento` | +0.3%/day | 0.4537 | 0.4764 | 0.4730 | 0.9522 |
| `ativacao` | +0.8%/day | 0.2571 | 0.2595 | 0.2991 | 0.9907 |
| `venda` | +1.2%/day | 0.0541 | 0.0587 | 0.0737 | 0.9218 |
| `demanda` | **+2.0%/day** | 0.2198 | 0.2308 | 0.3529 | 0.9524 |

**The error is not signed.** Two funnels read high, four read low, and the ratio spans 0.9218 to 1.9826.
A manager cannot carry a mental correction, because the correction changes sign with the growth of their
own pipeline.

And on `resgate` the dashboard exceeds the ceiling at **every stage**:

| Stage | `dashboard` | `ceiling` | Times above a rate it cannot exceed |
| --- | --- | --- | --- |
| respondeu | 0.2079 | 0.1468 | **1.4161** |
| abordado | 0.6683 | 0.5063 | 1.3200 |
| reativado | 0.0743 | 0.0602 | 1.2335 |
| elegivel | 0.7426 | 0.6100 | 1.2173 |

Six stages across the account read above their ceiling; four of them — all on `resgate` — by more than
sampling noise allows. **A conversion rate larger than the maximum achievable conversion rate is not a
conversion rate**, and that is not an argument about definitions, it is arithmetic.

## Why: two errors, pulling opposite ways

Step two of every funnel is the case where the algebra closes — a subject reaches it after one
exponential delay — so both readings have a closed form, and the simulation is checked against it rather
than against itself. The largest of the twelve deviations is **2.04**
standard errors of the derivation ([`tests/assert_closed_form.sql`](tests/assert_closed_form.sql)).

**The cohort reading has no growth term in it.** `cohort = p · (1 − e^(−W/m))` for a pass rate `p`, a
mean delay `m` and a maturity window `W`. A cohort is read at a fixed age, so the arrival shape cancels.
That property is what makes it a rate, and it is asserted as an identity.

**The dashboard reading is a steady-state estimator of the wrong quantity.** Hold arrivals flat and it
converges **exactly** on the eventual rate `p` — for any delay, to nine decimal places, which is
[`tests/assert_mechanisms.sql`](tests/assert_mechanisms.sql). It is not noisy and it is not biased about
`p`. It is answering *"what share eventually converts?"* when the question asked was *"what share
converts inside the month I am being measured on?"*

| Mean delay | `dashboard` | `ceiling` | `cohort` (30 days) | ratio |
| --- | --- | --- | --- | --- |
| 1 day | 0.4500 | 0.4500 | 0.4500 | 1.0000 |
| 10 days | 0.4500 | 0.4500 | 0.4276 | 1.0524 |
| 30 days | 0.4481 | 0.4500 | **0.2845** | **1.5754** |
| 60 days | 0.4212 | 0.4500 | **0.1771** | **2.3787** |

The dashboard column barely moves; the cohort column halves. The gap between the two is **the time the
funnel takes**, and a slow funnel reported this way looks like a fast one.

**Then growth breaks even that.** Hold the delay fixed and move only the arrivals:

| Arrivals | `dashboard` | `cohort` | ratio |
| --- | --- | --- | --- |
| −3%/day | 0.4871 | 0.4500 | **1.0825** |
| flat | 0.4500 | 0.4500 | 1.0000 |
| +3%/day | 0.4181 | 0.4500 | **0.9292** |

Monotone across all sixty-one points of the sweep, crossing one exactly at zero growth. Same funnel,
same behaviour: the dashboard reads **1.1651 times** as high at −3% a day as at +3%, bought entirely by
the direction of demand. A pipeline
that is filling reports a conversion rate that is falling, and the quarter it finally stops growing is
the quarter the rate appears to recover.

On `resgate` the two errors point the same way — arrivals are shrinking *and* the funnel takes 29 days
against a 30-day window — which is how one number ends up at 1.9826.

## And the same censoring, in the time dimension

Wave 1 asked what share of subjects reach a stage. The other half of a funnel review is how long they
take, and the same subjects are missing from that average: **the ones who have not reached the stage yet
are the slow ones.** A mean time-to-stage computed over the conversions in an event table is an average
over the survivors of a race still being run.

| Funnel | Arrivals | Actually takes | Reads as | reads ÷ actual | Restricted (30d) | Is slowest | **Reads slowest** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `retencao` | flat | **30.0 d** | 26.82 | 0.894 | 29.15 | **1st** | 2nd |
| `resgate` | −0.9%/day | 29.0 d | **29.07** | **1.002** | 29.64 | 2nd | **1st** |
| `demanda` | +2.0%/day | 27.0 d | 22.09 | **0.818** | 27.01 | 3rd | 3rd |
| `venda` | +1.2%/day | 23.0 d | 20.08 | 0.873 | 29.24 | 4th | 4th |
| `ativacao` | +0.8%/day | 19.0 d | 17.55 | 0.924 | 26.12 | 5th | 5th |
| `atendimento` | +0.3%/day | 5.2 d | 5.01 | 0.964 | 18.13 | 6th | 6th |

**The ranking inverts at the top.** `retencao` is the slowest funnel in the account and reads as the
second slowest; `resgate` is the second slowest and reads as the slowest. Nothing about either funnel's
behaviour is involved: `resgate`'s arrivals are *shrinking*, so its observed conversions come almost
entirely from old, fully matured cohorts and its reading is barely censored at all — **1.002** of the
truth. `retencao`'s flat arrivals still carry young cohorts, so its slow cases are still in flight.
The funnel that is measured most honestly is the one whose demand is dying.

**And unlike the rate, the time reading has no growth rate at which it is right.** Wave 1's dashboard
rate lands exactly on the eventual rate when arrivals are flat. Hold a twenty-day delay and sweep the
arrivals, and the time reading is fast *everywhere*:

| Arrivals | Actually takes | Reads as | reads ÷ actual |
| --- | --- | --- | --- |
| −3%/day | 20.0 d | 19.714 | 0.9857 |
| flat | 20.0 d | 17.511 | **0.8756** |
| +3%/day | 20.0 d | **12.514** | **0.6257** |

At flat arrivals it is still 12% fast, because the young cohorts exist whether or not they are growing.
At +3% a day the funnel reports **37% faster than it is**. Monotone across all sixty-one points, and
there is no fixed point to aim at.

**The measure that needs no assumption is not a duration.** `restricted` above is
`mean(min(time, 30 days))` over every subject of a mature cohort, counting anybody who had not converted
by day 30 at 30. It is defined for everybody, it requires nothing to be assumed about the unconverted,
and its closed form is `(1 − p)·W + p·m·(1 − e^(−W/m))` — but read what it does to `atendimento`: the
fastest funnel in the account by a factor of **5.77** reads only **1.61** times faster than the slowest,
because 52.7% of its subjects never reach `confirmado` and are counted at the window's edge. The measure
blends duration with completion by construction.

So the honest report is a **pair, not a number**: the restricted mean beside wave 1's cohort rate. Either
one alone can be moved by the other, and neither is identified without it.

Both time readings close algebraically at step two — the truncated mean
`m − W·e^(−W/m)/(1 − e^(−W/m))` and the restricted mean above — and the largest of the twelve deviations
is **1.11** standard errors, with the tolerance computed from the simulation's own spread rather than
from a binomial, because these are means.

## And the estimator that needs neither the discard nor the assumption

Waves 1 and 2 diagnosed the same thing twice, and wave 1's prescription — read cohorts old enough to have
finished — is correct and expensive. It refuses to look at any cohort younger than the maturity window,
which on this account is **14,093 of 47,317 subjects, 29.8%**. And the share grows with the growth rate:
the reading costs most data exactly where the business is moving fastest.

Kaplan and Meier's product-limit estimator discards nothing. Each subject contributes for as long as it
has been observed and then leaves the risk set — a subject that arrived four days ago tells the estimator
what happened in four days and is silent about the fifth. The curve is a running product over the risk
set at each event time, which is a window function over a sorted table: `sql/60_survival.sql` is one
query, and it needed no second language either.

| Funnel | `dashboard` | `cohort` | **Kaplan–Meier** | `truth` | KM error | cohort error | ratio |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `venda` qualificado | 0.4267 | 0.4464 | **0.4453** | 0.4500 | 0.00580 | 0.00699 | **0.8302** |
| `ativacao` configurado | 0.7820 | 0.7782 | 0.7833 | 0.7800 | 0.00670 | 0.00770 | 0.8701 |
| `retencao` em-risco | 0.2107 | 0.1656 | 0.1661 | 0.2200 | 0.00575 | 0.00605 | 0.9506 |
| `resgate` elegivel | 0.7426 | 0.5807 | 0.5820 | 0.6100 | 0.00966 | 0.00990 | 0.9756 |
| `atendimento` triado | 0.9553 | 0.9583 | 0.9582 | 0.9600 | 0.00167 | 0.00187 | 0.8953 |
| `demanda` classificada | 0.9101 | 0.9420 | 0.9408 | 0.9400 | 0.00207 | 0.00269 | **0.7698** |

**Same answer, tighter interval, on all twenty-two stages.** The ratio of standard errors runs from
**0.7698** to 0.9809 and never reaches one, which in sample-size terms is **1.24 times the data** on
average and **1.688 times** on `demanda` — the fastest-growing funnel, and therefore the one whose young
cohorts the cohort reading was throwing away. Three closed forms are verified at step two: the incidence
`p·(1 − e^(−W/m))` within **1.05** standard errors, the plateau against `p`, and the half-life against
`m·ln 2` to within 2.82%.

**And the median time to a stage usually does not exist.** A median needs more than half the subjects to
get there, and on this account **fourteen of the twenty-two stages** never do:

| Stage | Eventually convert | **Half-life** | Median |
| --- | --- | --- | --- |
| `atendimento` triado | 0.9582 | 0.139 d | 0.15 d |
| `demanda` priorizada | 0.6817 | 3.183 d | 5.17 d |
| `resgate` abordado | **0.4992** | 13.257 d | **none** |
| `venda` fechado | 0.0723 | **19.911 d** | **none** |
| `retencao` renovado | 0.1047 | 24.231 d | **none** |

`resgate` abordado misses having a median by **eight thousandths** of a conversion rate. So a report that
quotes a "median time to close" for a stage 7% of subjects reach has computed something else — almost
always the median among the ones who made it, which is a different population every month.

The quantity that is always defined is the **half-life**: the day by which half of the *eventual*
conversions have happened. Its closed form is `m·ln 2`, which contains no `p` at all — so it is the only
speed measure here that cannot be moved by a change in how many convert. Report it beside the plateau and
the two are identified; report either alone and the other one moves it.

**The limitation is the one assumption the estimator does make.** Censoring has to be unrelated to when a
subject would have converted. Here it is, by construction: the only thing censoring anybody is the
calendar. In a real funnel it frequently is not — records get archived, slow cases get a "lost" flag, a
pipeline review closes what looks stale — and every one of those censors the slow subjects *because* they
are slow, which is the one thing that breaks this estimator and cannot be detected from inside it.

## And the one assumption the estimator does make, broken on purpose

Wave 3 ended on a caveat: the product-limit estimator needs censoring to be unrelated to when a subject
would have converted, and a real funnel breaks that first. Breaking it turns out to require two steps,
and the first one is a finding on its own.

**An exponential delay cannot be broken by archiving, and that is why the exponential had to go.** Under
one exponential a subject open for twenty days is exactly as likely to convert tomorrow as one that opened
this morning, so removing a share of the slow ones removes nothing the estimator needed: the survivors
have the same future as the departed. A first attempt at this wave archived every stale record with one
probability and produced no bias at all — correctly, because a censoring rate that depends only on elapsed
time is exactly what the method allows.

So `sql/70_frailty.sql` splits the account into two declared classes — **30% slow at 2.5× the delay, 70%
fast at 0.357143×** — calibrated so the mean multiplier is **exactly 1**. The funnel is as fast on average
as it was in waves 1 to 3; only the spread changes. The estimator is still right: checked against the
two-exponential mixture's closed form, the largest deviation is **1.38** standard errors.

**But the spread alone makes the measured speed faster, at a true mean that has not moved.**

| Funnel | One exponential | Two classes | ratio |
| --- | --- | --- | --- |
| `retencao` | 17.2008 d | **14.5152 d** | **0.8439** |
| `resgate` | 9.7738 d | 8.8153 d | 0.9019 |
| `venda` | 1.9540 d | 1.8483 d | 0.9459 |
| `atendimento` | 0.2006 d | 0.2016 d | 1.0047 |

Heterogeneity pushes more of the slow class past the horizon where nobody can see it, so wave 2's naive
time reading loses another **15.6%** on `retencao` with no change in average speed whatever. Wave 2 assumed
one exponential and therefore **understated its own finding**.

**Then the review breaks the estimator, because a review is judgement rather than a stopwatch.** Somebody
opens the record, asks the account manager, and closes the ones that are genuinely dead — and that
judgement correlates with the class, which is the thing that made them slow. At the declared 21-day window
the review closes **9,541** records, of which **75.55%** are the slow class against **29.87%** of the
population: it is **2.529 times** more likely to close a slow record. Nothing in the data records the
class, which is why none of this is visible from inside: an analyst sees a censoring and cannot tell it
from the calendar.

| Review window | `retencao` (slow class 50 d) | `venda` (slow class 5 d) |
| --- | --- | --- |
| 3 days | **1.0450** | **0.9372** |
| 7 days | 1.0276 | 0.9700 |
| 14 days | 1.0036 | 0.9932 |
| 21 days | 1.0082 | 0.9986 |
| **30 days** | **1.0000** | **1.0000** |
| 60 days | 1.0000 | 1.0000 |

Two things in that table, and the second is the useful one.

**The bias has no sign.** `retencao` reads high and `venda` reads low, from the same review, at the same
window. Two effects fight: archiving hides conversions that would have happened, which pushes the estimate
*down*; and it removes subjects who were never going to convert from the risk set early, which pushes the
estimated hazard *up*. Which wins depends on the pass rate and on the slow class's delay against the
window — two parameters, not one. Across the sweep the ratio runs from **0.9372 to 1.0450**, seven points
above one and twenty-three below, and `resgate` changes sign *within* its own sweep. Not even the
magnitude is monotone: `retencao` reads 1.0036 at fourteen days and back up to 1.0082 at twenty-one.

**And there is an exact condition under which it cannot happen at all.** Every one of the eighteen sweep
points whose review window is at or beyond the reporting horizon is unbiased to machine precision —
because a review that removes nobody before day 30 cannot touch an estimate made at day 30. Inside the
horizon only six of thirty-six points are. So the rule is sharp and cheap to check:

> **A pipeline review whose window is shorter than the horizon you report on contaminates the report. One
> at or beyond it cannot.**

That is the whole prescription, and it needs no statistics to apply — only that somebody compare two
numbers that currently live in different documents: how long a record sits before the review closes it,
and how many days the conversion report covers.

## What to do instead

- **Read cohorts, and say the age.** "38% of the leads that arrived in March had closed within 60 days"
  is a sentence that survives a growing pipeline. "Conversion was 38% in May" does not.
- **Publish the delay next to the rate.** The gap between the eventual rate and the cohort rate *is* the
  delay; a funnel report without a time axis has quietly chosen the eventual rate and called it monthly.
- **Check the ceiling.** A stage reading above the product of its own historical step rates is the
  cheapest possible red flag, and it costs one query.
- **Ask what the arrivals did.** Before reading any movement in a funnel rate as behaviour, look at
  whether the top of the funnel grew. On this account that single question explains a factor of two.

## Running it

```bash
make duckdb   # fetch the DuckDB CLI into .bin, once
make build    # run every model in sql/, in order
make check    # build, then run every assertion in tests/
make report   # build, then print the published tables
```

`make check` is what gates a push, and it is what CI runs. There is no Python, no notebook and no
service to start: the whole repository is SQL files and one Makefile.

| Path | What it holds |
| --- | --- |
| [`sql/00_parameters.sql`](sql/00_parameters.sql) | Every declared number, the six funnels, and the generator written in arithmetic. |
| [`sql/10_subjects.sql`](sql/10_subjects.sql) | Arrivals per funnel per day, compounded at the declared growth. |
| [`sql/20_events.sql`](sql/20_events.sql) | The event log: one row per subject and per stage it actually reached. |
| [`sql/30_readings.sql`](sql/30_readings.sql) | The same funnel read four ways, and the distortion between two of them. |
| [`sql/40_closed_form.sql`](sql/40_closed_form.sql) | Both rate readings derived on paper, and the two mechanisms isolated. |
| [`sql/50_velocity.sql`](sql/50_velocity.sql) | The four readings again in the time dimension, their closed forms, and the speed ranking. |
| [`sql/60_survival.sql`](sql/60_survival.sql) | The product-limit estimator, its three closed forms, the precision it buys and the median that usually does not exist. |
| [`sql/70_frailty.sql`](sql/70_frailty.sql) | Two declared classes of subject at an unchanged mean delay, and the mixture's closed form. |
| [`sql/80_archiving.sql`](sql/80_archiving.sql) | The pipeline review that censors by judgement, what it costs the estimate, and the window at which it cannot. |
| [`tests/`](tests) | Eleven assertion files. Each returns the rows that break a claim; zero rows is a pass, and the harness checks the exit status too. |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | What is built, what is deliberately absent, what is still open, and the defects. |

## How the claims are kept honest

**Verification against a derivation, never against the code's own output.** Step two closes
algebraically, so the simulation is compared to arithmetic done separately. The tolerance is four
standard errors of a binomial proportion computed from the actual denominator — not a fixed number,
because `resgate` has 202 subjects in its window and `demanda` has 6,455.

**The generator is written in arithmetic rather than delegated to a library.** A seeded `random()` is a
promise made by whichever engine version happens to be installed. Here a uniform is a counter-based mix
of the draw's own index: no state, no seed, and no dependence on the order rows are evaluated in.

**Two controls hold the shape of the finding.** Arrival growth is swept with the delay fixed; the delay
is swept with arrivals flat. Each isolates one mechanism, and each is asserted as a monotone property
rather than as a figure.

**And defects are recorded rather than quietly fixed.** Seven so far, in
[`docs/ROADMAP.md`](docs/ROADMAP.md). The first generator passed the obvious test — the mean sat on
0.49999 and the range filled the interval — while two of its streams correlated at **−0.42**. The
second was an assertion of mine that was simply wrong: I asserted a population identity on a sample,
and six stages failed it by less than a standard error.

## Licence

MIT. See [`LICENSE`](LICENSE).
