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

Everything here is **SQL**. Twenty-four model files, twenty-one assertion files, a Makefile that decides the order, and
no second language: an assertion is a query that returns the rows which break it, so zero rows is a
pass and the harness needs no test framework. Every number in the documents below is re-derived by
`tests/assert_published_figures.sql`, so a change that moves a published figure breaks the build
instead of leaving the text quietly wrong.

No employer, client, customer or vendor data appears anywhere — see [`DISCLAIMER.md`](DISCLAIMER.md).

## Where to start

This page is organised by wave, which is the order the work happened in.
**[`docs/FINDINGS.md`](docs/FINDINGS.md) is the same material organised by the question you arrived
with** — thirty-four findings in seven groups, each naming the one query that prints it, the model that
produces it and the assertion that fails if it stops being true. That index is declared in
[`sql/g0_index.sql`](sql/g0_index.sql) and compiled against the repository by
[`tests/assert_index.sql`](tests/assert_index.sql), so it cannot quietly go stale.

[`docs/ROADMAP.md`](docs/ROADMAP.md) has every result wave by wave, what is deliberately absent, what is
still open, and the twenty-one recorded defects.

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

## And the funnel that is not a funnel at all: the queue inside `demanda`

Every wave above is about a *reading* being wrong. This one is not. `demanda` has a stage called
`priorizada`, and nothing in a pass rate or a delay contains the fact that makes prioritising a decision
at all: **the team works on one demand at a time, so putting this item first puts another item second.**
A delay is not a property of the demand. It is mostly the time the demand spends behind other demands.

So [`sql/90_queue.sql`](sql/90_queue.sql) replaces the delay of a stage with a server. One server, three
declared classes — 10% `critico` at 1.25 days of handling, 30% `padrao` at 0.75, 60% `melhoria` at 0.50 —
arriving Poisson at 1.2 a day, which leaves the server busy **0.78** of the time. That is M/G/1 with
non-preemptive priority, chosen because its mean waiting time is known on paper for every class under
every priority order, so every figure below is checked against arithmetic done separately.

Three orders are compared: first-come-first-served, `priority` (critical first), and `reversed` — which
is not a straw man, because clearing the quick items to make the backlog count fall is what teams
actually do under pressure, and `melhoria` is both the least urgent class and the cheapest to serve.

| Order | `critico` | `padrao` | `melhoria` | **mean wait per demand** |
| --- | --- | --- | --- | --- |
| first-come-first-served | 2.5461 d | 2.5624 d | 2.5632 d | **2.5612 d** |
| `priority` | **0.6961 d** | 1.1636 d | **4.3583 d** | **3.0358 d** (1.1853×) |
| `reversed` | **6.7375 d** | 2.3953 d | **0.9051 d** | **1.9382 d** (0.7568×) |

Every one of those nine numbers lands on its closed form — Cobham's formula for the priority orders,
Pollaczek and Khinchine's for first-come-first-served — the worst deviation being **1.293** standard
errors. The derivations are 0.6705, 1.1473 and 4.4261 days under `priority`, 6.9737, 2.4147 and 0.8957
under `reversed`, and 2.5868 for all three classes under first-come-first-served, which does not know the
classes exist.

### The total waiting does not move. At all.

The last column of that table is the number a service desk reports, and it swings by a factor of
**1.5663** between the two priority orders. Now weight each demand by the handling time it brings rather
than counting it once:

| Order | reported mean wait | mean wait per day of work |
| --- | --- | --- |
| first-come-first-served | 2.5612 d | **2.5540477739** d |
| `priority` | 3.0358 d | **2.5540477739** d |
| `reversed` | 1.9382 d | **2.5540477739** d |

That is not a coincidence and not a steady-state approximation. The area under the unfinished-work curve
over a busy period is the same under every discipline that never idles while work is waiting, and each
demand contributes `service × wait + service² / 2` to it. The second term does not depend on the order, so
`sum(service × wait)` **cannot** depend on the order — not approximately, not in expectation, but in
every realisation. It is asserted at a relative 1e-12 and holds to twelve decimal places at every
utilisation swept.

> **Prioritisation is not an improvement. It is an allocation.** The pool of waiting is fixed by how much
> work arrives and how fast the team is. A priority order decides who bears it, and nothing else.

And the metric that would tell a manager this is not the one on the dashboard. The reported mean wait
rises **18.5%** under the order that protects critical demands and falls **24.3%** under the order that
abandons them, because `melhoria` is both the most numerous class and the cheapest to serve. **The
service-desk KPI rewards the discipline that makes critical demands wait 6.7375 days.**

### What prioritising does buy, and the ceiling it cannot pass

| Order | `critico` meets its 2-day target | `melhoria` meets its 6-day target |
| --- | --- | --- |
| first-come-first-served | 0.3752 | 0.8486 |
| `priority` | **0.6295** | 0.7264 |
| `reversed` | 0.3207 | 0.9925 |

Prioritising is worth a real 25 points of critical attainment, and it is bought from `melhoria`. But
**0.7956** is the share of critical demands that would meet a two-day target *with no queue at all* — the
handling alone exceeds two days one time in five. So a fifth of that target was never reachable by
scheduling, at any utilisation, under any order. Ordering the queue closed 60% of the gap that ordering
could close, and the rest is a target written against a process whose own variation forbids it.

### One more percent of demand

Waiting is convex in utilisation, and the elasticity is exactly `1 / (1 − u)`:

| Utilisation | mean wait per day of work | % of waiting per % of demand |
| --- | --- | --- |
| 0.40 | 0.4925 d | 1.667 |
| 0.50 | 0.7408 d | 2.000 |
| 0.78 | 2.5957 d | **4.545** |
| 0.90 | 6.8417 d | 10.000 |
| 0.98 | 24.2435 d | 50.000 |

At the declared 0.78, one percent more demand buys four and a half percent more waiting; at 0.90 it buys
ten. By the invariance above, **no discipline changes a single row of that table.** The only levers on
total waiting are the amount of work arriving and the capacity serving it, and a prioritisation review
that produces neither has decided who waits without changing how much waiting there is.

### And the one error in this repository that does have a sign

Waves 1, 2 and 4 each found an error that changes sign with a parameter nobody reports, so no mental
correction exists. This one is different, and worse. The closed forms above are steady-state limits, and
what makes waiting large near capacity is a small number of very long busy periods — so as the server
fills up, the number of *independent* observations in a run collapses even though the number of demands
does not. At 0.98, one busy period holds **0.2121** of this entire 60,000-demand stream: 12,724 demands in
a single unbroken pile.

| Utilisation | 5,000 demands | 20,000 demands | 60,000 demands |
| --- | --- | --- | --- |
| 0.78 | 0.7048 | 0.9847 | 0.9873 |
| 0.95 | 0.4289 | 0.9367 | 0.9641 |
| 0.98 | 0.2442 | 0.6238 | **0.8422** |

Nine readings out of nine are **below** the truth, and near capacity even 60,000 demands reads 16% low.
A short observation of a queue does not scatter around the answer; it understates it, because the long
pile-ups that carry the mean are the ones a short window is least likely to contain. **The quantity a
capacity review most wants — how bad does it get when we are nearly full — is the one a finite
observation is least able to report, and the error is in the direction that feels safe.**

Which is not a hypothetical, because a quarterly review is a very short observation. Cut this unchanging
stream into consecutive 180-day slices — same arrival rate, same handling times, same discipline, same
utilisation, nothing different between them — and read each one the way a review would:

| | |
| --- | --- |
| Slices of 180 days | 277, averaging 216.6 demands each |
| True mean wait | 2.5318 d |
| Lowest slice reads | **0.6441 d** — attributable to a desk at 0.50 utilisation |
| Highest slice reads | **9.3057 d** — attributable to a desk at 0.90 utilisation |
| Highest over lowest | **14.4486×** |
| Interval a reviewer would draw (4 × sd/√n) | ± 0.6925 d |
| Interval the slices actually show | ± 5.8781 d |
| Understated by | **8.4879×** |

Nothing changed. The same desk, read one quarter at a time, reports a mean wait anywhere across a factor
of fourteen, and the confidence interval a reviewer would draw around it is eight times too narrow.

> **Before reading a change in a queue's waiting time as a change in the queue, ask how many independent
> pile-ups the reading contains.** Not how many tickets — how many times the queue emptied. At 0.78 that
> is a fifth of the ticket count; at 0.98 it is a fiftieth.

The interval is too narrow for a reason that matters beyond this table, and it is why every standard error
in this wave is a clustered one. Waits in a queue are not independent observations: a demand that waits a
long time arrived behind a pile, and so did the one after it. What *is* independent is the busy period —
each one starts with an empty system and carries no memory of the last. Treating 60,000 waits as 60,000
independent draws understates the interval by between **1.482** and **6.362** times depending on the class
and the order, worst for the class whose waiting is most caused by other demands. The cost is honest:
these closed-form checks can detect an error of **7.01%** to **20.23%** and no smaller, where the naive
interval would have claimed as little as **2.57%** and been wrong.

That busy period is the same object three times over. It makes the invariance exact, it makes the
interval honest, and it is what let the two priority orders be simulated at all: a 60,000-step recursion
becomes thousands of independent ones that run at once, precisely *because* no ordering of the queue can
move the instants at which the server goes idle.

## And the class nobody knows: the triage desk

Wave 5's queue serves the class. No intake desk can do that, because the class is not written on the
demand — somebody decides it, at the counter, on partial information, before the thing that makes the
demand urgent is known. From here on there are two classes per demand: **the one that determines what its
delay costs, and the one written on the ticket.** The queue serves the second.

[`sql/a0_triage.sql`](sql/a0_triage.sql) adds a declared confusion matrix between them — a critical demand
is recognised 75% of the time, a `melhoria` is escalated to `critico` 8% of the time — and re-runs the same
queue on the labels. The demands, the handling times and the utilisation are identical to wave 5's. Only
the line each demand stands in changes.

### The label is not the class

| Label | demands carrying it | share of all demands | share that belongs there |
| --- | --- | --- | --- |
| `critico` | 10084 | **0.1681** | **0.4509** |
| `padrao` | 22600 | 0.3767 | 0.5905 |
| `melhoria` | 27316 | 0.4553 | 0.9215 |

The critical class is 10% of demands. The critical *label* is 16.81% of them, and **fewer than half the
tickets carrying it belong there.** Of the 10084 tickets labelled `critico`, **4547** came from the critical
class and **5537** came from the other two — because the label collects a small share of two classes that are
three and six times larger than the one it is named after, and a small share of something large is larger
than a large share of something small. No failure of discipline is required.

### What it costs, and who it is paid to

| Class | wait if triage were perfect | wait under this desk | ratio | with no priority at all |
| --- | --- | --- | --- | --- |
| `critico` | 0.6961 d | **1.0383 d** | **1.4916** | 2.5461 d |
| `padrao` | 1.1636 d | 1.6401 d | 1.4095 | 2.5624 d |
| `melhoria` | 4.3583 d | **3.8716 d** | **0.8883** | 2.5632 d |

The genuinely critical demands wait **49.2% longer** than they would under a desk that never errs, and
their two-day target attainment falls from 0.6295 to 0.5941. The `melhoria` class is **better off**.

That is not a coincidence and it is the reason this wave exists. Relabelling the queue cannot change how
much work is in it, so wave 5's invariance has to survive a desk that mislabels a third of its calls — and
it does, exactly:

| | work-weighted waiting | against perfect triage |
| --- | --- | --- |
| Perfect critical-first priority | 99015.6062 | — |
| This triage desk | 99015.6062 | **1.000000000000** |

> **A triage error is not waste. It is a transfer.** Every extra day the critical class waits is a day some
> other class does not, and the other class is whoever the wrong label sent to the front.

Both halves of the arithmetic are checked separately. Cobham's formula applies to the *labels*, whose
service distributions are now mixtures: 0.6957, 1.3640 and 5.0720 days, against 0.7042, 1.3984 and 4.9970
simulated, the worst deviation 0.867 clustered standard errors. The wait of a true class is then a
conditional average over the labels its members land in, which predicts 1.0482 days for `critico` against
1.0383 simulated — 0.257 standard errors. It is the only figure in this repository that is a composition of
two derivations, so it is the only one checked at both levels.

### And the dashboard improves

The reported mean wait per demand under perfect critical-first priority is 3.0358 days. Under this triage
desk it is **2.9201** — the metric a service desk publishes gets **better** as the triage desk gets worse,
because over-escalation moves the numerous, cheap demands to the front and only the critical few pay.

It is worse than that. Take all six orders three classes can be served in, derive each one, and sort them
by what they truly cost at the declared urgency:

| Order | cost at declared urgency | against the best | reported mean wait |
| --- | --- | --- | --- |
| `p1 p2 p3` | **5.2657** | 1.0000 | 3.0691 d |
| `p2 p1 p3` | 5.6603 | 1.0749 | 3.0240 d |
| `p1 p3 p2` | 7.5822 | 1.4399 | 2.4900 d |
| `p3 p1 p2` | 8.6627 | 1.6451 | 2.3160 d |
| `p2 p3 p1` | 10.8461 | 2.0598 | 2.1891 d |
| `p3 p2 p1` | **11.7533** | 2.2321 | **1.9622 d** |

The work-weighted total is 2.0174602407 in every row, as it must be. The reported mean wait falls
monotonically down the table. **The metric ranks the six possible priority orders in exactly the reverse of
their true cost — all six, not approximately.** An operation that optimises its published mean handling
time is choosing the worst available order, and the numbers will show it improving the whole way.

### The two ways to be wrong are not worth the same

Swept one at a time, in closed form, against the critical class's waiting under perfect triage:

| Error rate | over-escalation | under-recognition |
| --- | --- | --- |
| 5% | 1.0385 | **1.2675** |
| 10% | 1.0800 | **1.5278** |
| 20% | 1.1739 | 2.0280 |
| 50% | 1.5883 | 3.3826 |
| 100% | 3.8580 | **5.2470** |

At a tenth, failing to recognise a critical demand costs the critical class **52.8%** and escalating a
routine one costs it **8.0%** — a factor of **6.6**. The work-weighted total is unmoved at all sixteen
points. And the two limits are not symmetric in a way that matters:

- Escalate **everything** and the critical class waits 3.8580 times its ideal, which is exactly the
  first-come-first-served wait. Total over-escalation is no worse than never having sorted the queue.
- Miss **everything** and it waits 5.2470 times its ideal, which is *worse* than never having sorted it.

So there is a rate at which a priority system stops being worth having, and it is computable: past **0.62**
under-recognition, the genuinely critical demands would be better off in an unsorted queue. Sorting a queue
by a label that is wrong often enough is not a weak version of sorting it. It is active misdirection.

### The right order is not the urgent one

Wave 5 proved no order changes the total, so the only thing an order does is decide who waits — and
deciding requires saying what waiting costs. [`sql/00_parameters.sql`](sql/00_parameters.sql) declares that
as an exchange rate rather than money: a day of delay on `critico` is worth 10 days on `melhoria`, `padrao`
3. Given costs, the order that minimises weighted waiting is known, and it is **not** "most urgent first":

> Rank by **urgency divided by mean handling time**, not by urgency.

| Class | urgency | mean handling | urgency per day of handling | margin before the order swaps |
| --- | --- | --- | --- | --- |
| `critico` | 10 | 1.2381 d | **8.0768** | **1.9797** |
| `padrao` | 3 | 0.7353 d | 4.0797 | **2.0497** |
| `melhoria` | 1 | 0.5024 d | 1.9904 | — |

The rule reproduces `p1 p2 p3`, the winner of the six — so on this account intuition is right. The column
worth reading is the last one. The margin protecting the intuitive answer is a factor of **two**, not a
factor of ten, and it is the ratio of two numbers no escalation policy contains. Sweeping the critical
class's handling time at constant critical workload — the same work arriving as many quick incidents or a
few slow ones — locates the breaking point exactly:

| Critical handling time | what critical-first costs against standard-first |
| --- | --- |
| 0.5000 d | 0.8046 |
| 1.2381 d *(declared)* | 0.9303 |
| 2.4000 d | 0.9982 |
| **2.4512 d** | **the threshold** |
| 2.5000 d | 1.0016 |
| 6.0000 d | 1.0544 |

At 2.4512 days of handling, critical-first stops being the best order. The threshold is exactly
`urgency(critico) × handling(padrao) ÷ urgency(padrao)`, and it contains no arrival rate and no utilisation.
**A class blocks the queue in proportion to how long it takes to clear, and urgency does not scale with
that.** The major-incident bridge that occupies the whole team for three days while two hundred standard
requests pile up behind it is not a failure of execution. It is what the declared policy asks for, past a
threshold the policy never states.

### Which of the two levers to pull

Both findings are on one scale, and they are not worth the same effort:

| | cost at declared urgency |
| --- | --- |
| Perfect triage, best order | 5.2657 |
| Perfect triage, next-best order | 1.0749× |
| **This triage desk, best order** | **1.1157×** |
| Perfect triage, worst order | 2.2321× |

A realistic mistake in the *order* costs 7.5%. The declared triage desk costs **11.6%** — and the critical
class does not feel 11.6% of it. It feels **1.5632** times its ideal waiting, a **56.3%** excess, roughly
five times the excess the account as a whole carries. A prioritisation review spends its time arguing about
the order. The order is the cheaper problem.

## And what it costs to know: the triage desk spends the capacity it protects

Wave 6 gave the desk an error rate and charged nothing for it. That is the last fiction left. Classifying
takes looking, and the person looking is the person working — so **accuracy is bought with the only thing
the priority order ever had to allocate.**

[`sql/b0_effort.sql`](sql/b0_effort.sql) makes that explicit. Each look costs the server **0.02 days**
(about half an hour) and reports the true class with probability **0.70**, otherwise picking uniformly
between the other two. The label is the mode of `looks` independent looks. Nothing about the confusion
matrix is declared any more: it falls out of an exact multinomial over the ways the votes can land, so
accuracy is *derived* from effort. It is checked against a draw from the declared generator anyway — nine
cells, worst deviation **2.093** standard errors.

### Accuracy is not monotone in effort

| Looks | `critico` | `padrao` | `melhoria` |
| --- | --- | --- | --- |
| 1 | 0.7000 | 0.7000 | 0.7000 |
| **2** | **0.9100** | 0.7000 | **0.4900** |
| 3 | 0.8785 | 0.7840 | 0.7840 |
| **4** | 0.9163 | 0.8501 | **0.7840** |
| 8 | 0.9712 | 0.9481 | 0.9250 |

An even number of looks can tie, and a tie has to be broken by rule. The declared rule sends ties to the
more urgent class — which is what a desk under pressure does — and the consequence is exact: **two looks
leave `melhoria` worse than one look**, 0.4900 against 0.7000. The second look does not add information to
that class, it adds a coin flip that the tie-break resolves against it.

And the fourth look buys the bottom class **nothing at all** — 0.7840 at three looks, 0.7840 at four. A
full look of capacity, spent, for exactly zero. **Odd effort helps every class; even effort only helps
whichever class the tie-break favours.**

That tie-break is a pure transfer, and the mirror is exact. Under the lenient rule at two looks the numbers
are 0.4900 / 0.7000 / 0.9100 — the same three figures, reversed. The rule creates no accuracy. It moves it.
At two looks the choice between the two rules is worth **7.6569 against 8.5145** on the declared urgency
scale, an **11.2%** swing from a line that appears in no triage policy.

### The optimum is one look, and three is worse than none

| Looks | utilisation | `critico` wait | `melhoria` wait | cost | against no triage |
| --- | --- | --- | --- | --- | --- |
| 0 *(no triage)* | 0.7799 | 2.5868 d | 2.5868 d | 7.8212 | 1.0000 |
| **1** | 0.8040 | 1.5789 d | 4.3030 d | **7.1449** | **0.9135** |
| 2 | 0.8282 | 1.1868 d | 5.3872 d | 7.6569 | 0.9790 |
| 3 *(declared)* | 0.8523 | 1.3364 d | 6.8672 d | 8.7071 | **1.1133** |
| 5 | 0.9006 | 1.2124 d | 11.7301 d | 12.1307 | 1.5510 |
| 8 | 0.9730 | 1.5938 d | 51.0349 d | 41.6458 | **5.3248** |

One look pays 8.7%. Two looks pay 2.1%. **Three looks — the declared scenario — costs 11.3% more than not
triaging at all**, and eight looks costs **5.3 times** more. The declared effort is deliberately past the
optimum: a parameter tuned to the answer would have hidden the answer.

Half an hour per demand, eight times over, is 0.16 days of triage. That alone takes utilisation from 0.7799
to 0.9730 and multiplies the waiting of the same queue with no priority order from 2.5868 to **26.3007
days** — a factor of **ten**, bought with nothing but looking.

**And past a certain effort the critical class itself is worse off.** `critico` waits 1.5789 days at one
look, bottoms out at 1.2124 at five, and is back to **1.5938 at eight** — worse than at one look. The class
the triage exists to protect is harmed by triage, because the triage is standing in its queue.

### How carefully to classify is not a property of the desk

It is a property of how full the desk already is. Sweeping the utilisation *before* triage:

| Utilisation before triage | looks worth spending | looks even possible | against no triage |
| --- | --- | --- | --- |
| 0.40 | 1 | 8 | 0.9629 |
| 0.60 | 1 | 8 | 0.9268 |
| **0.75** | 1 | 8 | **0.9112** |
| 0.85 | 1 | 5 | 0.9451 |
| 0.88 | 1 | 4 | 0.9874 |
| **0.89** | **0** | 3 | **1.0000** |
| 0.95 | **0** | **1** | 1.0000 |

Three things in that table.

**Triage stops paying at 0.89.** Past it, the effort that would buy a better label costs more waiting than
the better label saves, and the correct policy is to sort nothing and look at nothing.

**The gain peaks in the middle, at 0.75 and 8.9%.** Below it there is little waiting to reallocate, so a better label
is worth less; above it the looking is ruinous. Triage earns its keep in a band, roughly 0.60 to 0.85, and
is worth most where a desk is busy but not drowning.

**And the ceiling collapses before the optimum does.** At 0.78 the desk could perform eight looks; at 0.85
only five; at 0.95 **exactly one**, because a second look would push utilisation past one and the queue
would have no steady state at all.

> **The busier the desk, the less it can afford to know.** Which is the exact opposite of what happens:
> when a queue explodes, the first response is a triage meeting.

### The three waves together

Wave 5 proved no priority order can reduce the total waiting — only decide who bears it. Wave 6 showed the
label the order sorts by is not the class, and that getting it wrong is a transfer rather than a loss. Wave
7 prices getting it right, and finds the price is charged in the same currency the order was allocating.

So the arc closes on a single prescription, and it is not a scheduling prescription:

> **At high utilisation there is one lever, and it is capacity.** Sorting cannot help, classifying makes it
> worse, and classifying stops working before sorting does.

The one simplification worth naming: the classification time is bundled into the demand's handling time
rather than charged as its own stage at intake. That is the conservative choice, and deliberately so — real
triage is paid *before* the sorting happens, so it blocks the queue earlier than this model does and costs
more, not less.

## And the sophistication that loses to one look

Wave 7 spends the same effort on every demand, which no desk does. A real one stops early on the obvious
ones and keeps looking at the ambiguous ones. [`sql/c0_stopping.sql`](sql/c0_stopping.sql) builds that: after
each look the posterior over the three classes is recomputed from Bayes, and the desk commits as soon as the
largest posterior crosses a declared threshold. The threshold parameterises the whole range in one number —
the largest prior share is 0.60, so **"do not triage" is not a separate policy here, it is the low end of
this one.**

This wave was built to show that the stopping rule wins. It does not, and the reason is worth more than the
result would have been.

### The effort does go where it is needed

| Threshold | `critico` | `padrao` | `melhoria` |
| --- | --- | --- | --- |
| 0.70 | 2.3810 looks | 2.4352 | 1.5747 |
| 0.80 | **3.6572 looks** | 2.6283 | **1.8143** |
| 0.90 | 4.8597 looks | 3.5532 | 3.2911 |

At the declared 0.80 the desk spends **2.0158 times** as many looks confirming a critical demand as an
improvement, and it is not being careless — it is being correct. The prior is 0.10 against `critico`, so
committing to it requires more evidence. That part of the design works exactly as intended.

But look at what it costs. `critico` is already the slowest class to handle, at 1.2381 days. It is now also
the slowest to classify. **The class that blocks the queue most is the class most expensive to recognise**,
and the two compound.

### And the labels come out worse where it matters

| Rule at its own optimum (θ = 0.65) | labels correct | `critico` correct | cost |
| --- | --- | --- | --- |
| Maximise accuracy | **0.7872** | **0.5590** | 7.6623 |
| Minimise expected cost | 0.7307 | 0.6789 | **7.4580** |
| *One fixed look (wave 7)* | *0.7000* | *0.7000* | ***7.1449*** |

Three things, and the third is the wave.

**The accuracy-maximising rule recognises the critical class 0.5590 of the time** — worse than the 0.7000 a
single raw look achieves by simply reporting what it saw. Bayes shrinks toward the base rate; the base rate
says "probably not critical"; and wave 6 established that failing to recognise a critical demand costs 6.6
times what escalating a routine one costs. **Every unit of statistical correctness is paid for in the
currency the operation cares about.**

**Making the rule cost-aware confirms the diagnosis.** Commit to the class with the largest posterior
*times its declared urgency* instead of the largest posterior, and the cost falls from 7.6623 to 7.4580 —
better at every threshold above the degenerate one — while getting **fewer labels right**, 0.7307 against
0.7872. *Fewer correct labels, less waiting.* Both halves of that are asserted.

**And both still lose to one fixed look.** Not by much — 4.4% for the cost-aware rule — but they lose.

### At every utilisation, including the ones with slack

| Utilisation before triage | best threshold | constant looks | stopping ÷ constant |
| --- | --- | --- | --- |
| 0.40 | 0.65 | 1 | 1.0144 |
| 0.60 | 0.65 | 1 | 1.0216 |
| 0.78 | 0.65 | 1 | 1.0439 |
| 0.82 | 0.65 | 1 | **1.0569** |
| 0.88 | 0.60 | 1 | 1.0128 |
| 0.89 and above | 0.60 | 0 | 1.0000 |

I expected the sequential rule to win where there is slack, on the reasoning that cheap capacity makes
accuracy affordable. It never wins. At 0.40 utilisation — where looking costs almost nothing — one raw look
still beats the best stopping rule by 1.4%, because the rule's disadvantage is not its cost. It is its
objective. Using the prior is what makes it lose, and the prior does not get cheaper when the server
empties.

> **A single raw look, escalating on whatever it reports, beats every Bayesian refinement of it — because
> the refinement shrinks toward a base rate that is against the one class you cannot afford to miss.**

That is why good triage protocols are written as rule-out criteria and not as probability estimates. "If any
indicator of severity is present, escalate" is the raw-look rule. "Estimate the probability and act on the
most likely case" is the rule this wave shows losing. The first is worse at labelling and better at not
missing, and only the second of those is on the scoreboard.

### One cost that is real and negligible

Because the effort is now an outcome rather than a parameter, it has a variance — and Pollaczek and
Khinchine's residual work charges the *second* moment of the service time, of which the triage time is part.
So a rule that looks a variable number of times costs more than a rule that looks E[K] times exactly. The
mechanism is real; the size, here, is not: **1.0015 at worst**, a fifth of one percent, because a look
costs 0.02 days against a handling time of 0.6461. It would matter if looking were expensive relative to
doing, and it is worth naming so that a reader knows when to care.

### Waves 5 to 8

| | |
| --- | --- |
| Wave 5 | No priority order reduces the total waiting. It only decides who bears it. |
| Wave 6 | The label the order sorts by is not the class, and getting it wrong is a transfer, not a loss. |
| Wave 7 | Getting it right costs the capacity that makes labels matter. Past 0.89 utilisation, do not triage. |
| Wave 8 | And the sophisticated way of getting it right is worse than the crude way, at every utilisation. |

> **Look once. Escalate on any indication. Spend the argument on capacity.**

## And the stage that is not a stage: subjects that skip, fall back and come back

Every reading in waves 1 to 4 rests on a shape nobody states out loud: a subject occupies one stage at a
time, moves forward, and stops. That is what makes "reached stage k" a well-defined event, "the rate at
stage k" a fraction of a fixed denominator, and the product of the pass rates an upper bound nothing can
exceed. [`sql/d0_movements.sql`](sql/d0_movements.sql) builds a second event log where subjects break all
three: some **skip** a stage, some **fall back** to the one before, and some **come back** weeks later and
start again.

Same subjects, same arrival days, same forward coins. Entry one attempt one draws the salts the monotone log
of [`sql/20_events.sql`](sql/20_events.sql) was built from, so the control is exact rather than approximate:
for every subject whose skip coin came up tails, **all 127122 rows match to the day**, and
[`tests/assert_movements.sql`](tests/assert_movements.sql) fails if a single one does not. Every difference
between the two logs is a movement, and nothing else.

The size of the difference first: **174745 rows against 137923**, a ratio of **1.2670** on the same
population. 11195 of the extra rows are second entries, 29583 are the way back up from a fallback, and
29452 subject-stages are visited more than once. A schema with one row per subject per stage cannot hold
any of them.

### The ceiling stops being a ceiling

Wave 1's cheapest diagnostic was that **a stage reading above the product of its own pass rates proves the
reading is not a rate.** It costs one query and it was the most portable thing in this repository. Here is
what a skip does to it.

A first entry reaches step three either by passing step two and then step three, or by skipping step two and
then passing step three. So the reach is `[(1-s)·p₂ + s]·p₃` against a declared ceiling of `p₂·p₃`, which is
above it by exactly

```
1 + s·(1 - p₂)/p₂
```

for any skip rate at all — because **the skipper was never subject to the coin the ceiling is built from.**

| `venda`, mature cohorts | monotone log | messy log | declared ceiling |
| --- | --- | --- | --- |
| `proposta` | 0.2374 | **0.2911** | 0.2475 |
| ÷ ceiling | 0.9590 | **1.1762** | 1.0 |

The messy reading is **17.62% above a bound it is not allowed to exceed**, on a generator that is obeying
every declared rate to four standard errors. The derived ratio for `venda` is **1.1467** and the simulated
first-entry reach is **0.2764** against a derivation of **0.2838** — inside tolerance, which is four
standard errors of the share and not a fixed epsilon.

So the diagnostic produces a false alarm on a healthy funnel. That would be bad enough. It is worse than
that, and the second half is the finding.

### And it is silent on the funnel that is being bypassed

`retencao` is skipped at only 0.05, but its step-two pass rate is low, so the derived breach is **1.1773** —
*larger* than `venda`'s. Its windowed cohort reading is **0.1449** against a ceiling of **0.1496**. It reads
*below* the ceiling. The maturity window this whole repository is about censors the slow walks the skip is
adding, and the two effects cancel to something under one.

> **One diagnostic, both error directions at once: it fires on a funnel that is fine and stays quiet on a
> funnel that is being bypassed. It is not a diagnostic. It is a question — "can this stage be skipped?" —
> and it cannot tell the answer from a broken metric.**

I got this wrong twice while building it, in both directions, which is why the derivation now names its
population and its horizon in the file itself. Defects 16 and 17 in [`docs/ROADMAP.md`](docs/ROADMAP.md).

### The denominator is not the number of subjects

A re-entry adds a second row at the entry stage. A fallback adds a second row at a middle stage. A funnel
read by counting rows inflates **both ends** of every fraction, by different factors, and which one wins
depends on where subjects gave up.

| Stage | events ÷ subjects | event-counted ÷ subject-counted |
| --- | --- | --- |
| `venda` `proposta` | 1.2009 | **1.0594** |
| `venda` `negociacao` | 1.2256 | **1.0812** |
| `retencao` `em-risco` | 1.1585 | **0.9229** |

The bias has **no sign**. A correction factor would need one, and the same event log produces
overstatement and understatement at different stages. `tests/assert_movements.sql` asserts that both
directions occur, so a future change that makes the bias tidy breaks the build.

### And "time to reach" is two numbers

| `venda` `negociacao` | |
| --- | --- |
| Mean first touch | 15.29 days |
| Mean last touch | 18.04 days |
| Gap | **2.7503 days** |
| Share of subjects that visited it twice | **0.2049** |

A fifth of the subjects reach that stage twice, and the two honest answers to "how long does it take to
reach negotiation" are 18% apart. Nothing in the schema records which one a report meant, and `min` versus
`max` in a `GROUP BY` is not a decision anybody documents.

### Waves 1 to 4, revisited

| | |
| --- | --- |
| Wave 1 | A funnel rate is a cohort statement, and the window reading is the censoring. |
| Wave 4 | The ceiling is the cheapest check there is. |
| Wave 9 | And it holds only while a stage is a stage. Skips break the bound; re-entries break the denominator; fallbacks break the clock. |

> **Before reading any funnel, ask whether a subject can be in two stages, in none, or in the same one
> twice. If it can, the number on the dashboard has no denominator.**

## And the change somebody shipped: the lift that is only a delay

Waves 1 to 9 measure a funnel. This one measures a **decision**. Six changes are shipped on the same day,
one per funnel, and [`sql/e0_interventions.sql`](sql/e0_interventions.sql) builds both the world where they
were shipped and the world where they were not — the same subjects, the same coin streams, walked twice. Two
of the six raise a pass rate. Two move only a delay and leave the eventual rate **exactly** alone. One moves
both. One is a placebo: announced, shipped, and does nothing.

The construction earns the word *causal*, which is not a word this repository uses lightly:

- **Common random numbers.** The changed world reads the same uniform draw against a larger threshold, so a
  subject that cleared a stage before still clears it. A multiplier at or above one cannot make anybody worse
  off, and that is asserted as an exact property rather than a tendency: **107, 76 and 447 subjects gained a
  conversion, and zero lost one, across the three changes that raised a rate.**
- **Two exact controls.** Subjects that arrived before the change reproduce wave 1's log to the day (46734
  rows), and so does every counterfactual (98124 rows). Both are checked row for row.
- **A counterfactual no operation has.** The effect is measured against the same population that received the
  change, so there is no pre-period, no growth, and no mix to argue about. That column is the answer key, and
  it is the reason the errors below are the reading's and not the sample's.

### What the six changes did

| Funnel | change | true lift |
| --- | --- | --- |
| `venda` | closing rate ×1.25 | **+0.2512** |
| `retencao` | risk-flagging rate ×1.30 | **+0.3207** |
| `demanda` | rate ×1.10 and delay ×0.60 | **+0.1041** |
| `ativacao` | delay ×0.50, rate untouched | **0.0** |
| `resgate` | delay ×0.40, rate untouched | **0.0** |
| `atendimento` | nothing | **0.0** |

The three zeros are exact, not small: a change that moves only a delay moves no conversion at all, because
whether a subject eventually reaches a stage does not depend on how long it took. The reach sets of the two
worlds are identical, row for row. Only the dates differ, and `tests/assert_interventions.sql` asserts both
halves — that no conversion moved, and that the dates did.

### The reading a dashboard takes gets it backwards

Thirty days of conversions before the change against thirty days after it, which is the comparison in every
launch review:

| Funnel | window before | window after | **apparent lift** | true lift |
| --- | --- | --- | --- | --- |
| `ativacao` | 0.2353 | 0.3285 | **+0.3962** | **0.0** |
| `demanda` | 0.2019 | 0.2338 | +0.1581 | +0.1041 |
| `resgate` | 0.0803 | 0.0826 | +0.0294 | **0.0** |
| `venda` | 0.0614 | 0.0627 | **+0.0218** | **+0.2512** |
| `retencao` | 0.1013 | 0.1027 | **+0.0132** | **+0.3207** |
| `atendimento` | 0.4724 | 0.4659 | −0.0139 | 0.0 |

Read that table twice. **The biggest win on the page converted nobody.** The two changes that genuinely
raised conversion — by a quarter and by a third — read as +2.2% and +1.3%, which any reviewer would call
noise. The real lift is 11.5 and 24.3 times the reported one.

The mechanism is wave 1's, applied to a decision instead of a rate. The conversions landing inside the
thirty days after a launch belong mostly to subjects who arrived *before* it, so a rate change is almost
invisible there. A speed-up, by contrast, pulls conversions that were already going to happen forward across
the window boundary, and the window counts every one of them as new.

> **A launch that moves your cycle time will beat a launch that moves your conversion rate on any
> before-and-after report, every time. The first shows up immediately and the second shows up after the
> funnel's own delay.**

### And no single horizon can tell them apart

Compare the two worlds properly — same cohorts, both read at the same maturity — and sweep the horizon:

| Horizon | `ativacao` (true 0) | `resgate` (true 0) | `venda` (true +0.25) | `retencao` (true +0.30) |
| --- | --- | --- | --- | --- |
| 10 days | **+0.6374** | +3.0 | +0.2683 | +0.1613 |
| 20 days | **+0.4022** | **+0.5385** | +0.2245 | **+0.1892** |
| 30 days | **+0.1593** | **+0.2174** | +0.2513 | +0.2391 |
| 60 days | +0.0047 | +0.0357 | +0.32 | +0.4286 |

A pure speed-up starts enormous and decays toward zero as the horizon outlasts the funnel. A real rate lift
converges toward its true value. **At any single horizon the two look the same**, and the shape across
horizons is the only thing that separates them — which is why reading a launch once, at whatever maturity the
report happens to use, cannot answer the question it was commissioned to answer.

### The ranking a review receives

| At 20 days | measured | true | true rank |
| --- | --- | --- | --- |
| 1st `resgate` | +0.5385 | **0.0** | 6th |
| 2nd `ativacao` | +0.4022 | **0.0** | 5th |
| 3rd `demanda` | +0.3399 | +0.1041 | 3rd |
| 4th `venda` | +0.2245 | +0.2512 | 2nd |
| 5th `retencao` | **+0.1892** | **+0.3207** | **1st** |

At the twenty-day horizon the two changes that converted nobody rank **first and second**, and the change
that converted the most people ranks **below both of them**. At thirty days the page looks respectable and is
still wrong: the two real lifts are in the wrong order, and a change worth nothing is credited with +0.2174.

> **Before ranking interventions by measured lift, check whether any of them changed a cycle time. If one
> did, the ranking is a ranking of cycle times.**

Defects 18 and 19 in [`docs/ROADMAP.md`](docs/ROADMAP.md) — a standard error priced on the wrong scale, and
an undefined ratio that DuckDB ranked first because it orders `nan` above every real number.

## And the reading that moved because the population moved

Every wave so far measures one population. There isn't one. Subjects arrive through origins that convert
at different rates, and the share arriving through each origin moves — which makes every aggregate reading
a weighted average whose weights are themselves a time series, and nothing in a funnel report says so.

[`sql/f0_segments.sql`](sql/f0_segments.sql) gives each of wave 1's subjects one of three origins and walks
it again. The arrival counts are untouched, so no earlier figure moves. What changes is that the second
stage's pass rate is the declared rate times the origin's multiplier — and both the origin shares and the
multipliers drift across the horizon.

**Both periods are halves of the mature horizon.** Every cohort in them had the full maturity window to
convert, so wave 1's prescription is already applied to every figure below. Whatever moves here is not the
window. That is the point: this is a second mechanism, orthogonal to the first, and fixing the first does
nothing whatsoever about it.

### Every origin got better. The total got worse.

| Origin | first half | second half | change |
| --- | --- | --- | --- |
| `direto` | 0.6430 | 0.7022 | **+0.0592** |
| `parceiro` | 0.4551 | 0.4983 | **+0.0432** |
| `campanha` | 0.2343 | 0.2515 | **+0.0172** |
| **Aggregate** | **0.4890** | **0.4544** | **−0.0347** |

Not one origin declined. The number on the dashboard fell by three and a half points, on 12388 and 20836
subjects, and the fall is six standard errors wide.

The reason is in the shares: `direto` fell from 0.4642 of arrivals to 0.2838 while `campanha` rose from
0.2415 to 0.4126. The best origin shrank and the worst one grew, and the composition moved further than
the rates did.

This is not a sampling story at all. The same reversal is in the declared parameters, with the arrival
weighting that wave 1's growth mechanism requires — **the composition of a period is the arrival-weighted
average of its daily shares, not the share at its midpoint**, because the late days of a period carry more
subjects than the early ones:

| Declared | first half | second half |
| --- | --- | --- |
| `direto` multiplier | 0.9082 | **0.9252** |
| `parceiro` multiplier | 0.6465 | **0.6595** |
| `campanha` multiplier | 0.3272 | **0.3399** |
| **Weighted average** | **0.692221** | **0.605715** |

Three numbers up, their average down. That is arithmetic, not evidence.

### The decomposition that has no remainder

The change splits into what happened inside the origins and what happened to their weights. Written with
the *mean* of the two periods' shares and rates —

```
Δ(Σ w·p) = Σ (w₀+w₁)/2 · (p₁−p₀)  +  Σ (p₀+p₁)/2 · (w₁−w₀)
```

— the two terms add to the change **exactly**. The algebra collapses to `Σw₁p₁ − Σw₀p₀` with nothing left
over, which is why the assertion on it is at machine precision rather than within a tolerance.

| Pooled | |
| --- | --- |
| Change in the aggregate | −0.034664 |
| Inside the origins | **+0.040673** |
| Between the origins (the mix) | **−0.075337** |
| Residual | **0.0** |
| Mix ÷ within | **1.8523** |

The mix effect is **1.85 times** the within-origin effect and points the other way. And the familiar
textbook split — rate change at the *starting* shares, share change at the *starting* rates — leaves the
cross term `Σ Δw·Δp` unaccounted for: **−0.007324, a fifth of the whole movement.** A decomposition with a
leftover gets the leftover named "interaction" and then interpreted.

### One different set of weights

Hold the composition at the first half's shares and read the second half's rates:

| | reported | standardised |
| --- | --- | --- |
| Pooled | **−0.0347** | **+0.0443** |
| `demanda` | **−0.0864** | **+0.0078** |

Same subjects, same conversions, same definition of converted. The sign flips. And `demanda` is the
starkest case in the table: standardised, it moved by less than a percentage point; as reported, it lost
more than eight. **The entire movement was who arrived.**

> **A funnel rate is a weighted average, and the weights are a time series nobody plots. Before explaining
> why a rate moved, standardise the mix and see whether it moved at all.**

### The finding I did not want

The first version of this wave declared a thirty-point share drift and compared two narrow windows. The
aggregate fall came out at **three standard errors** — entirely real, exactly what the arithmetic predicts,
and not distinguishable from noise at the four-standard-error bar this repository uses everywhere else.

The wrong response is to loosen the bar for one result. The right response was more data, and when the full
mature horizon was still not enough, a larger declared drift — stated in
[`sql/00_parameters.sql`](sql/00_parameters.sql) rather than quietly applied. But the measurement is worth
more than the fix: **a mix shift large enough to reverse the sign of a reported trend sits at the edge of
what a few months of data can resolve.** Which is why, in practice, this reversal is argued about rather
than demonstrated — and why the decomposition, which needs no sample at all to be exact, is the thing to
put in front of a review.

Defects 20 and 21 in [`docs/ROADMAP.md`](docs/ROADMAP.md).

## What to do instead

- **Read cohorts, and say the age.** "38% of the leads that arrived in March had closed within 60 days"
  is a sentence that survives a growing pipeline. "Conversion was 38% in May" does not.
- **Publish the delay next to the rate.** The gap between the eventual rate and the cohort rate *is* the
  delay; a funnel report without a time axis has quietly chosen the eventual rate and called it monthly.
- **Check the ceiling.** A stage reading above the product of its own historical step rates is the
  cheapest possible red flag, and it costs one query.
- **Ask what the arrivals did.** Before reading any movement in a funnel rate as behaviour, look at
  whether the top of the funnel grew. On this account that single question explains a factor of two.
- **Weight waiting by the work it carries, not by the ticket count.** The ticket-weighted mean can be
  improved by serving the cheap items first, and doing so makes the critical ones wait longer. The
  work-weighted mean cannot be improved by any ordering at all, which is exactly why it is the one worth
  reporting: it moves only when something real moves.
- **Bring a prioritisation proposal and a capacity number to the same meeting.** Prioritisation decides
  who waits. Only the work arriving and the capacity serving it decide how much waiting there is, and at
  0.78 utilisation one percent more demand costs four and a half percent more waiting.
- **Count how many times the queue emptied, not how many items it handled.** That is the sample size of
  any statement about waiting. A quarter of this desk contains 216.6 demands and about forty-eight
  pile-ups, which is why one quarter of it can read anywhere across a factor of fourteen with nothing
  having changed.
- **Check a service target against the handling time alone before blaming the queue.** A fifth of the
  critical demands here miss a two-day target on handling time by itself. No scheduling can recover that,
  and a review that spends its time on sequencing will keep missing by that fifth.
- **Audit what is in the top label before arguing about the order.** Fewer than half the tickets labelled
  critical here belong there, and that alone costs the genuinely critical class 49.2% of its waiting. The
  order is the cheaper problem: a realistic mistake in it costs 7.5% against triage's 11.6%.
- **Spend triage effort on recognising the urgent, not on suppressing the inflated.** Failing to spot a
  critical demand costs it 6.6 times what escalating a routine one costs it, at the same error rate. Past
  0.62 under-recognition the priority system is worse for the critical class than no priority system.
- **Divide urgency by handling time before you rank.** The order that minimises what waiting costs is
  urgency per day of handling, not urgency. On this account the two agree — by a factor of two, which is the
  ratio of two numbers no escalation policy writes down.
- **Never let a mean handling time judge a priority policy.** Across all six orders three classes can be
  served in, the reported mean wait ranks them in exactly reverse order of their true cost.
- **Price the triage before buying it.** Classification time is served by the same server as the work, so
  it raises the utilisation the priority order exists to manage. One look per demand pays 8.7% here; three
  cost 11.3% *more* than not triaging at all.
- **Check the utilisation before asking for a better label.** The effort worth spending falls as the desk
  fills and reaches zero at 0.89, and the number of looks that are even feasible collapses first — at 0.95
  a second look would push utilisation past one. When a queue explodes, a triage meeting is the wrong
  reflex: at that point the only lever is capacity.
- **Write down the tie-break.** An even number of checks produces ties, and the rule that resolves them
  transfers accuracy between classes without creating any. Here it swings the total cost by 11.2%, and it
  appears in no policy document.
- **Prefer an odd number of checks to an even one.** Going from three to four costs a full look of capacity
  and buys the bottom class exactly nothing — 0.7840 either way.
- **Write the protocol as a rule-out, not as an estimate.** "Escalate if any indicator of severity is
  present" beats "estimate the probability and act on the most likely case" here at every utilisation from
  0.40 to 0.95. A probability estimate shrinks toward the base rate, and the base rate is against the class
  whose misclassification costs the most.
- **If you must weigh evidence, weigh it by cost and not by likelihood.** Committing to the class with the
  largest posterior times its urgency beats committing to the largest posterior at every threshold — while
  getting *fewer* labels right.

- **Ask whether a stage can be skipped before trusting the ceiling.** A stage reading above the product of
  its pass rates is the cheapest red flag there is, and it fires on a perfectly healthy funnel the moment
  any subject can bypass a step — by 17.62% here. It also stays silent on a funnel that *is* being bypassed,
  when the stage delays are long enough for the maturity window to hide it. Use it to ask the question, never
  to answer it.
- **Count subjects, not rows, and say which you counted.** Re-entries inflate the top of the funnel and
  fallbacks inflate the middle, so row-counting biases the same report in both directions at once. There is
  no factor to divide by.
- **Say first touch or last touch.** Where a stage can be visited twice, "time to reach it" is two numbers
  18% apart, and `min` versus `max` inside a `GROUP BY` is the most consequential undocumented decision in
  a funnel report.

- **Never read a launch on a before-and-after window.** The conversions inside the window after a launch
  mostly belong to arrivals from before it, so a real rate change is nearly invisible and a cycle-time change
  is enormous. Here the two genuine conversion lifts read as +2.2% and +1.3% while a change that converted
  nobody read as +39.6% and topped the page.
- **Ask what the change was supposed to do before reading what it did.** A change to a delay and a change to
  a rate move the same reported number in the same direction. Only one of them creates a conversion, and no
  single-horizon reading distinguishes them.
- **Read the lift at several maturities and look at the shape.** A rate lift converges upward toward a
  constant; a speed-up decays toward zero. One reading is an anecdote; the curve is the diagnostic.
- **Ship a placebo occasionally.** A measurement system that has never produced a null result has not been
  shown to be capable of producing one.

- **Standardise the mix before explaining the move.** A funnel rate is a weighted average and the weights
  are a time series nobody plots. Here every origin improved and the total fell by three and a half points;
  holding the composition fixed turns that into a four-point rise. Both numbers are correct and they
  describe different questions.
- **Decompose, and use the form that has no remainder.** Weighting each change by the mean of the two
  periods makes the split exact. The textbook version drops the cross term — a fifth of the movement here —
  and a leftover in a decomposition gets named "interaction" and then interpreted.
- **Report the composition next to the rate.** If the share of your best-converting origin fell eighteen
  points, that is the finding, and no amount of discussion of conversion tactics will reach it.
- **Expect not to be able to prove it.** A mix shift big enough to reverse a reported trend is at the edge
  of what a quarter of data can resolve. The decomposition is exact with no sample at all; the significance
  test on the aggregate usually is not. Argue from the first.

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
| [`sql/90_queue.sql`](sql/90_queue.sql) | One server, three priority classes, three disciplines: the waiting each one produces, the total that does not move, the utilisation sweep and what a 180-day slice can say. |
| [`sql/95_queue_closed_form.sql`](sql/95_queue_closed_form.sql) | The queue derived on paper — Pollaczek–Khinchine, Cobham, and the conservation law the invariance is an instance of. |
| [`sql/a0_triage.sql`](sql/a0_triage.sql) | The label the queue actually serves: a declared confusion matrix, the queue re-run on it, what each class loses and who it is paid to. |
| [`sql/a5_urgency.sql`](sql/a5_urgency.sql) | Cobham on the labels composed onto the classes, both error directions swept, all six orders enumerated, and the rule that names the winner. |
| [`sql/b0_effort.sql`](sql/b0_effort.sql) | Accuracy derived from effort by an exact multinomial, checked against a draw; what the looking costs the server; and the interior optimum. |
| [`sql/b5_effort_sweep.sql`](sql/b5_effort_sweep.sql) | The effort worth spending against the utilisation already carried, and the point past which triage stops paying at all. |
| [`sql/c0_stopping.sql`](sql/c0_stopping.sql) | A sequential desk: the posterior walk, both labelling objectives over the same walk, and what the effort's variance costs. |
| [`sql/c5_stopping_sweep.sql`](sql/c5_stopping_sweep.sql) | The best stopping rule against one fixed look, at every utilisation — the comparison that came out the other way. |
| [`sql/d0_movements.sql`](sql/d0_movements.sql) | A second event log where subjects skip a stage, fall back to the one before, and come back — same subjects, same forward coins. |
| [`sql/d5_movement_readings.sql`](sql/d5_movement_readings.sql) | The same readings taken on both logs, the step-three closed form, and what row-counting does to the denominator. |
| [`sql/e0_interventions.sql`](sql/e0_interventions.sql) | Six changes shipped on one day, and the world where they were not — the same subjects and the same coins, walked twice. |
| [`sql/e5_lift_readings.sql`](sql/e5_lift_readings.sql) | The causal lift, the lift measured at six horizons, the before-and-after window reading, and the ranking a review receives. |
| [`sql/f0_segments.sql`](sql/f0_segments.sql) | Three origins with drifting shares and drifting conversion, assigned to wave 1's own subjects. |
| [`sql/f5_mix_readings.sql`](sql/f5_mix_readings.sql) | The two-period reading, the exact decomposition into within and between, the standardised rate, and the same reversal in the declared parameters. |
| [`sql/g0_index.sql`](sql/g0_index.sql) | The index of findings, declared as rows so that the table of contents is compiled rather than written. |
| [`tests/`](tests) | Seventeen assertion files. Each returns the rows that break a claim; zero rows is a pass, and the harness checks the exit status too. |
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

**The interval accounts for what is actually independent.** Waves 1 to 4 use four standard errors of a
binomial or of a sample mean. Wave 5 cannot: a queue's waits are correlated inside a busy period, so
`sd/√n` understates the interval by up to 6.362 times. Every standard error in the queue is clustered on
busy periods, which are independent because each one starts with an empty system — and the cost in power is
published rather than hidden.

**And defects are recorded rather than quietly fixed.** Twenty-one so far, in
[`docs/ROADMAP.md`](docs/ROADMAP.md). The first generator passed the obvious test — the mean sat on
0.49999 and the range filled the interval — while two of its streams correlated at **−0.42**. The
second was an assertion of mine that was simply wrong: I asserted a population identity on a sample,
and six stages failed it by less than a standard error.

## Licence

MIT. See [`LICENSE`](LICENSE).
