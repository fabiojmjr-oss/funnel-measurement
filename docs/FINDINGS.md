# Findings, by the question you arrived with

*[Versão em português](FINDINGS.pt-BR.md) · [README](../README.md) · [Roadmap](ROADMAP.md) · [Disclaimer](../DISCLAIMER.md)*

The [README](../README.md) and the [roadmap](ROADMAP.md) are organised by wave, which is the order
the work happened in. This is the other organisation: **thirty-four findings grouped by the question
a reader shows up with**, each one naming the query that prints it, the model that produces it and
the assertion that fails if it stops being true.

Every row is declared in [`sql/g0_index.sql`](../sql/g0_index.sql) and checked against the
repository by [`tests/assert_index.sql`](../tests/assert_index.sql). A report nothing points at, a
file that moved, a figure the build does not already pin, or a wave nobody indexed fails
`make check` — so this page cannot quietly stop being true, which is the only kind of index worth
reading.

To see any finding for yourself:

```bash
make duckdb && make build
.bin/duckdb build/funnels.duckdb -box -c ".read docs/report_50_ceiling.sql"
```

---

## Contents

1. [Is the number a rate?](#is-the-number-a-rate) — 8 findings
2. [How long does it take?](#how-long-does-it-take) — 5 findings
3. [Does the estimator survive the data?](#does-the-estimator-survive-the-data) — 3 findings
4. [Who waits, and can reordering fix it?](#who-waits-and-can-reordering-fix-it) — 5 findings
5. [Can the label be trusted?](#can-the-label-be-trusted) — 7 findings
6. [Did the change work?](#did-the-change-work) — 3 findings
7. [Is it the same population?](#is-it-the-same-population) — 3 findings


## Is the number a rate?

### 1.1 Wave 1 — `1.9826`

The same six funnels read as improving or collapsing, and the only parameter that differs in kind is whether arrivals grow.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_10_funnels.sql`](../docs/report_10_funnels.sql) | [`sql/30_readings.sql`](../sql/30_readings.sql) | [`tests/assert_mechanisms.sql`](../tests/assert_mechanisms.sql) |

### 1.2 Wave 1 — `0.9218`

One funnel read four ways, stage by stage. The four disagree, and only one of them is the conversion rate.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_20_stages.sql`](../docs/report_20_stages.sql) | [`sql/30_readings.sql`](../sql/30_readings.sql) | [`tests/assert_events.sql`](../tests/assert_events.sql) |

### 1.3 Wave 1 — `1.4161`

Move the arrival growth and hold the delay: the cohort reading does not move at all.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_30_mechanisms.sql`](../docs/report_30_mechanisms.sql) | [`sql/40_closed_form.sql`](../sql/40_closed_form.sql) | [`tests/assert_mechanisms.sql`](../tests/assert_mechanisms.sql) |

### 1.4 Wave 1 — `1.0825`

Move the delay and hold arrivals flat: the dashboard reading sits on the eventual rate while the cohort reading falls away from it.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_40_delay.sql`](../docs/report_40_delay.sql) | [`sql/40_closed_form.sql`](../sql/40_closed_form.sql) | [`tests/assert_closed_form.sql`](../tests/assert_closed_form.sql) |

### 1.5 Wave 1 — `2.3787`

Six stages read above the product of their own pass rates, which is a bound a rate cannot exceed.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_50_ceiling.sql`](../docs/report_50_ceiling.sql) | [`sql/30_readings.sql`](../sql/30_readings.sql) | [`tests/assert_events.sql`](../tests/assert_events.sql) |

### 1.6 Wave 9 — `1.1762`

And that bound stops being a bound the moment a stage can be skipped: a healthy funnel breaches it by a sixth.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_j1_ceiling_breach.sql`](../docs/report_j1_ceiling_breach.sql) | [`sql/d5_movement_readings.sql`](../sql/d5_movement_readings.sql) | [`tests/assert_movements.sql`](../tests/assert_movements.sql) |

### 1.7 Wave 9 — `1.0812`

Counting rows instead of subjects biases the same report in both directions at once, so there is no factor to divide by.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_j2_denominators.sql`](../docs/report_j2_denominators.sql) | [`sql/d5_movement_readings.sql`](../sql/d5_movement_readings.sql) | [`tests/assert_movements.sql`](../tests/assert_movements.sql) |

### 1.8 Wave 9 — `1.2670`

One row per subject per stage is not a storage choice: the messy log is a quarter larger on the same population.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_j0_movements.sql`](../docs/report_j0_movements.sql) | [`sql/d0_movements.sql`](../sql/d0_movements.sql) | [`tests/assert_movements.sql`](../tests/assert_movements.sql) |


## How long does it take?

### 2.1 Wave 2 — `0.818`

The measured speed ranks the funnels differently from their actual speed, and the inversion is at the top.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_60_velocity.sql`](../docs/report_60_velocity.sql) | [`sql/50_velocity.sql`](../sql/50_velocity.sql) | [`tests/assert_velocity.sql`](../tests/assert_velocity.sql) |

### 2.2 Wave 2 — `5.77`

There is no arrival growth rate at which the naive time reading is correct, unlike the rate reading, which is exact at flat arrivals.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_70_velocity_growth.sql`](../docs/report_70_velocity_growth.sql) | [`sql/50_velocity.sql`](../sql/50_velocity.sql) | [`tests/assert_velocity.sql`](../tests/assert_velocity.sql) |

### 2.3 Wave 3 — `19.911`

The median time to a stage usually does not exist, because fewer than half the subjects ever arrive there.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_90_timing.sql`](../docs/report_90_timing.sql) | [`sql/60_survival.sql`](../sql/60_survival.sql) | [`tests/assert_survival.sql`](../tests/assert_survival.sql) |

### 2.4 Wave 3 — `29.8`

The product-limit estimator gives the cohort reading's answer without discarding a third of the subjects, and with a tighter interval.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_80_survival.sql`](../docs/report_80_survival.sql) | [`sql/60_survival.sql`](../sql/60_survival.sql) | [`tests/assert_survival.sql`](../tests/assert_survival.sql) |

### 2.5 Wave 4 — `0.8439`

Extra spread alone makes the measured speed faster, at a true mean that has not moved.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_a0_frailty.sql`](../docs/report_a0_frailty.sql) | [`sql/70_frailty.sql`](../sql/70_frailty.sql) | [`tests/assert_frailty.sql`](../tests/assert_frailty.sql) |


## Does the estimator survive the data?

### 3.1 Wave 4 — `1.0450`

A pipeline review that archives what looks dead breaks the estimator, and the bias has no sign.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_b0_archiving.sql`](../docs/report_b0_archiving.sql) | [`sql/80_archiving.sql`](../sql/80_archiving.sql) | [`tests/assert_archiving.sql`](../tests/assert_archiving.sql) |

### 3.2 Wave 5 — `0.8422`

Every reading of the same unchanging queue is below the truth, and the shortfall grows with utilisation.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_d1_run_length.sql`](../docs/report_d1_run_length.sql) | [`sql/90_queue.sql`](../sql/90_queue.sql) | [`tests/assert_queue.sql`](../tests/assert_queue.sql) |

### 3.3 Wave 5 — `216.6`

One quarter of an unchanging desk can read anywhere across a factor of fourteen with nothing having changed.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_e0_measurability.sql`](../docs/report_e0_measurability.sql) | [`sql/90_queue.sql`](../sql/90_queue.sql) | [`tests/assert_queue.sql`](../tests/assert_queue.sql) |


## Who waits, and can reordering fix it?

### 4.1 Wave 5 — `2.5461`

Every discipline moves who waits. None of them moves the work-weighted total.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_c0_queue.sql`](../docs/report_c0_queue.sql) | [`sql/90_queue.sql`](../sql/90_queue.sql) | [`tests/assert_queue.sql`](../tests/assert_queue.sql) |

### 4.2 Wave 5 — `2.5540477739`

The work-weighted total waiting is identical under every work-conserving order, to twelve decimal places, in every realisation.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_c1_invariance.sql`](../docs/report_c1_invariance.sql) | [`sql/95_queue_closed_form.sql`](../sql/95_queue_closed_form.sql) | [`tests/assert_queue_closed_form.sql`](../tests/assert_queue_closed_form.sql) |

### 4.3 Wave 5 — `4.545`

Waiting is convex in utilisation with elasticity exactly 1/(1-u): at 0.78, one percent more demand costs four and a half percent more waiting.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_d0_utilisation.sql`](../docs/report_d0_utilisation.sql) | [`sql/95_queue_closed_form.sql`](../sql/95_queue_closed_form.sql) | [`tests/assert_queue_closed_form.sql`](../tests/assert_queue_closed_form.sql) |

### 4.4 Wave 6 — `3.0691`

Across all six orders three classes can be served in, the reported mean wait ranks them in exactly reverse order of their true cost.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_g0_orders.sql`](../docs/report_g0_orders.sql) | [`sql/a5_urgency.sql`](../sql/a5_urgency.sql) | [`tests/assert_urgency.sql`](../tests/assert_urgency.sql) |

### 4.5 Wave 6 — `2.4512`

The order that minimises cost is urgency divided by handling time, and past a derived threshold critical-first is the wrong order.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_g1_handling.sql`](../docs/report_g1_handling.sql) | [`sql/a5_urgency.sql`](../sql/a5_urgency.sql) | [`tests/assert_urgency.sql`](../tests/assert_urgency.sql) |


## Can the label be trusted?

### 5.1 Wave 6 — `49.2`

Fewer than half the tickets labelled critical belong there, and that alone costs the genuinely critical class half of its waiting.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_f0_triage.sql`](../docs/report_f0_triage.sql) | [`sql/a0_triage.sql`](../sql/a0_triage.sql) | [`tests/assert_triage.sql`](../tests/assert_triage.sql) |

### 5.2 Wave 6 — `0.62`

Past a certain rate of under-recognition the priority system is worse for the critical class than no priority system at all.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_f1_escalation.sql`](../docs/report_f1_escalation.sql) | [`sql/a0_triage.sql`](../sql/a0_triage.sql) | [`tests/assert_triage.sql`](../tests/assert_triage.sql) |

### 5.3 Wave 7 — `0.4900`

Accuracy is not monotone in effort: two looks leave the bottom class worse than one, because an even number of looks produces ties.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_h0_accuracy.sql`](../docs/report_h0_accuracy.sql) | [`sql/b0_effort.sql`](../sql/b0_effort.sql) | [`tests/assert_effort.sql`](../tests/assert_effort.sql) |

### 5.4 Wave 7 — `26.3007`

Classification time is served by the same server as the work, so a sixth of a day of triage per demand multiplies the same queue's waiting by ten.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_h1_effort_cost.sql`](../docs/report_h1_effort_cost.sql) | [`sql/b0_effort.sql`](../sql/b0_effort.sql) | [`tests/assert_effort.sql`](../tests/assert_effort.sql) |

### 5.5 Wave 7 — `8.9`

How carefully to classify is not a property of the desk but of how full it is: past 0.89 utilisation the effort worth spending is zero.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_h2_effort_optimum.sql`](../docs/report_h2_effort_optimum.sql) | [`sql/b5_effort_sweep.sql`](../sql/b5_effort_sweep.sql) | [`tests/assert_effort.sql`](../tests/assert_effort.sql) |

### 5.6 Wave 8 — `2.0158`

The class that blocks the queue most is the class most expensive to recognise, and the two compound.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_i0_stopping.sql`](../docs/report_i0_stopping.sql) | [`sql/c0_stopping.sql`](../sql/c0_stopping.sql) | [`tests/assert_stopping.sql`](../tests/assert_stopping.sql) |

### 5.7 Wave 8 — `1.0569`

A single raw look beats every Bayesian refinement of it, at every utilisation, because the refinement shrinks toward a base rate that is against the class you cannot afford to miss.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_i1_stopping_versus_constant.sql`](../docs/report_i1_stopping_versus_constant.sql) | [`sql/c5_stopping_sweep.sql`](../sql/c5_stopping_sweep.sql) | [`tests/assert_stopping.sql`](../tests/assert_stopping.sql) |


## Did the change work?

### 6.1 Wave 10 — `0.3962`

A change that moves only a delay moves no conversion at all, and the before-and-after window reading puts it top of the page anyway.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_k0_interventions.sql`](../docs/report_k0_interventions.sql) | [`sql/e0_interventions.sql`](../sql/e0_interventions.sql) | [`tests/assert_interventions.sql`](../tests/assert_interventions.sql) |

### 6.2 Wave 10 — `0.6374`

No single horizon separates a rate change from a speed change. Only the shape of the lift across horizons does.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_k1_horizon.sql`](../docs/report_k1_horizon.sql) | [`sql/e5_lift_readings.sql`](../sql/e5_lift_readings.sql) | [`tests/assert_interventions.sql`](../tests/assert_interventions.sql) |

### 6.3 Wave 10 — `0.5385`

At a twenty-day horizon the two changes that converted nobody rank first and second, above the change that converted the most people.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_k2_ranking.sql`](../docs/report_k2_ranking.sql) | [`sql/e5_lift_readings.sql`](../sql/e5_lift_readings.sql) | [`tests/assert_interventions.sql`](../tests/assert_interventions.sql) |


## Is it the same population?

### 7.1 Wave 11 — `0.4544`

Every origin got better at converting and the total got worse, because the best origin's share of arrivals fell eighteen points.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_m0_mix.sql`](../docs/report_m0_mix.sql) | [`sql/f0_segments.sql`](../sql/f0_segments.sql) | [`tests/assert_segments.sql`](../tests/assert_segments.sql) |

### 7.2 Wave 11 — `1.8523`

The mean-weighted decomposition of the change is exact. The textbook one drops a cross term worth a fifth of the movement.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_m1_decomposition.sql`](../docs/report_m1_decomposition.sql) | [`sql/f5_mix_readings.sql`](../sql/f5_mix_readings.sql) | [`tests/assert_segments.sql`](../tests/assert_segments.sql) |

### 7.3 Wave 11 — `0.0443`

Holding the composition at the first period's shares flips the sign of the reported change.

| Run | Built by | Guarded by |
| --- | --- | --- |
| [`docs/report_m2_standardised.sql`](../docs/report_m2_standardised.sql) | [`sql/f5_mix_readings.sql`](../sql/f5_mix_readings.sql) | [`tests/assert_segments.sql`](../tests/assert_segments.sql) |

---

## What is not in here

Four models and five assertions carry no finding of their own, and both lists are declared in
[`sql/g0_index.sql`](../sql/g0_index.sql) rather than left implicit — the assertion requires the
index and those two lists to partition `sql/` and `tests/` exactly, so a new file cannot be added
without being either indexed or explicitly excused.

The models build the world every finding is measured in: the declared parameters and the generator,
the arrivals, the monotone event log that three later waves use as their control, and this index.
The assertions guard the repository's own conventions rather than a finding: that the parameters are
consistent, that the generator draws what it claims, that every figure quoted in prose is
re-derived, that the documents agree with each other, and that this index agrees with the
repository it indexes.

The twenty-one recorded defects are in [`docs/ROADMAP.md`](ROADMAP.md), with the wave each one was
found in. They are not findings about funnels — they are findings about this repository, and several
of them are the most transferable thing in it.
