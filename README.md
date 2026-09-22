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

Everything here is **SQL**. Five model files, seven assertion files, a Makefile that decides the order, and
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
| [`sql/40_closed_form.sql`](sql/40_closed_form.sql) | Both readings derived on paper, and the two mechanisms isolated. |
| [`tests/`](tests) | Seven assertion files. Each returns the rows that break a claim; zero rows is a pass, and the harness checks the exit status too. |
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

**And defects are recorded rather than quietly fixed.** Three so far, in
[`docs/ROADMAP.md`](docs/ROADMAP.md). The first generator passed the obvious test — the mean sat on
0.49999 and the range filled the interval — while two of its streams correlated at **−0.42**. The
second was an assertion of mine that was simply wrong: I asserted a population identity on a sample,
and six stages failed it by less than a standard error.

## Licence

MIT. See [`LICENSE`](LICENSE).
