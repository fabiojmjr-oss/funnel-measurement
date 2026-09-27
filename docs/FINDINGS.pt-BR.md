# Achados, pela pergunta com que você chegou

*[English version](FINDINGS.md) · [README](../README.pt-BR.md) · [Roadmap](ROADMAP.md) · [Aviso](../DISCLAIMER.md)*

O [README](../README.pt-BR.md) e o [roadmap](ROADMAP.md) são organizados por onda, que é a ordem em
que o trabalho aconteceu. Esta é a outra organização: **trinta e quatro achados agrupados pela
pergunta com que um leitor chega**, cada um nomeando a consulta que o imprime, o modelo que o produz
e a asserção que falha se ele deixar de ser verdade.

Toda linha é declarada em [`sql/g0_index.sql`](../sql/g0_index.sql) e conferida contra o repositório
por [`tests/assert_index.sql`](../tests/assert_index.sql). Um relatório que ninguém aponta, um arquivo
que mudou de lugar, uma figura que o build ainda não fixa, ou uma onda que ninguém indexou quebram o
`make check` — então esta página não pode deixar de ser verdade em silêncio, que é o único tipo de
índice que vale ler.

Para ver qualquer achado você mesmo:

```bash
make duckdb && make build
.bin/duckdb build/funnels.duckdb -box -c ".read docs/report_50_ceiling.sql"
```

---

## Índice

1. [O número é uma taxa?](#o-número-é-uma-taxa) — 8 achados
2. [Quanto tempo leva?](#quanto-tempo-leva) — 5 achados
3. [O estimador sobrevive aos dados?](#o-estimador-sobrevive-aos-dados) — 3 achados
4. [Quem espera, e reordenar resolve?](#quem-espera-e-reordenar-resolve) — 5 achados
5. [O rótulo é confiável?](#o-rótulo-é-confiável) — 7 achados
6. [A mudança funcionou?](#a-mudança-funcionou) — 3 achados
7. [É a mesma população?](#é-a-mesma-população) — 3 achados


## O número é uma taxa?

### 1.1 Onda 1 — `1,9826`

Os mesmos seis funis leem como melhorando ou desabando, e o único parâmetro que difere em natureza é se as chegadas crescem.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_10_funnels.sql`](../docs/report_10_funnels.sql) | [`sql/30_readings.sql`](../sql/30_readings.sql) | [`tests/assert_mechanisms.sql`](../tests/assert_mechanisms.sql) |

### 1.2 Onda 1 — `0,9218`

Um funil lido de quatro maneiras, estágio por estágio. As quatro discordam, e só uma delas é a taxa de conversão.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_20_stages.sql`](../docs/report_20_stages.sql) | [`sql/30_readings.sql`](../sql/30_readings.sql) | [`tests/assert_events.sql`](../tests/assert_events.sql) |

### 1.3 Onda 1 — `1,4161`

Mexa no crescimento das chegadas e segure o atraso: a leitura por coorte não se move nem um pouco.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_30_mechanisms.sql`](../docs/report_30_mechanisms.sql) | [`sql/40_closed_form.sql`](../sql/40_closed_form.sql) | [`tests/assert_mechanisms.sql`](../tests/assert_mechanisms.sql) |

### 1.4 Onda 1 — `1,0825`

Mexa no atraso e segure as chegadas planas: a leitura de painel fica sobre a taxa eventual enquanto a de coorte se afasta dela.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_40_delay.sql`](../docs/report_40_delay.sql) | [`sql/40_closed_form.sql`](../sql/40_closed_form.sql) | [`tests/assert_closed_form.sql`](../tests/assert_closed_form.sql) |

### 1.5 Onda 1 — `2,3787`

Seis estágios leem acima do produto das próprias taxas de passagem, que é um limite que uma taxa não pode exceder.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_50_ceiling.sql`](../docs/report_50_ceiling.sql) | [`sql/30_readings.sql`](../sql/30_readings.sql) | [`tests/assert_events.sql`](../tests/assert_events.sql) |

### 1.6 Onda 9 — `1,1762`

E esse limite deixa de ser limite no instante em que um estágio pode ser pulado: um funil saudável o viola por um sexto.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_j1_ceiling_breach.sql`](../docs/report_j1_ceiling_breach.sql) | [`sql/d5_movement_readings.sql`](../sql/d5_movement_readings.sql) | [`tests/assert_movements.sql`](../tests/assert_movements.sql) |

### 1.7 Onda 9 — `1,0812`

Contar linhas em vez de sujeitos enviesa o mesmo relatório nas duas direções ao mesmo tempo, então não existe fator por que dividir.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_j2_denominators.sql`](../docs/report_j2_denominators.sql) | [`sql/d5_movement_readings.sql`](../sql/d5_movement_readings.sql) | [`tests/assert_movements.sql`](../tests/assert_movements.sql) |

### 1.8 Onda 9 — `1,2670`

Uma linha por sujeito por estágio não é escolha de armazenamento: o log confuso é um quarto maior na mesma população.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_j0_movements.sql`](../docs/report_j0_movements.sql) | [`sql/d0_movements.sql`](../sql/d0_movements.sql) | [`tests/assert_movements.sql`](../tests/assert_movements.sql) |


## Quanto tempo leva?

### 2.1 Onda 2 — `0,818`

A velocidade medida ranqueia os funis de forma diferente da velocidade real, e a inversão está no topo.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_60_velocity.sql`](../docs/report_60_velocity.sql) | [`sql/50_velocity.sql`](../sql/50_velocity.sql) | [`tests/assert_velocity.sql`](../tests/assert_velocity.sql) |

### 2.2 Onda 2 — `5,77`

Não existe taxa de crescimento de chegadas em que a leitura ingênua de tempo esteja correta, ao contrário da leitura de taxa, exata com chegadas planas.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_70_velocity_growth.sql`](../docs/report_70_velocity_growth.sql) | [`sql/50_velocity.sql`](../sql/50_velocity.sql) | [`tests/assert_velocity.sql`](../tests/assert_velocity.sql) |

### 2.3 Onda 3 — `19,911`

O tempo mediano até um estágio geralmente não existe, porque menos da metade dos sujeitos chega lá.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_90_timing.sql`](../docs/report_90_timing.sql) | [`sql/60_survival.sql`](../sql/60_survival.sql) | [`tests/assert_survival.sql`](../tests/assert_survival.sql) |

### 2.4 Onda 3 — `29,8`

O estimador produto-limite dá a resposta da leitura por coorte sem descartar um terço dos sujeitos, e com intervalo mais estreito.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_80_survival.sql`](../docs/report_80_survival.sql) | [`sql/60_survival.sql`](../sql/60_survival.sql) | [`tests/assert_survival.sql`](../tests/assert_survival.sql) |

### 2.5 Onda 4 — `0,8439`

Só o acréscimo de dispersão deixa a velocidade medida mais rápida, com a média verdadeira parada.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_a0_frailty.sql`](../docs/report_a0_frailty.sql) | [`sql/70_frailty.sql`](../sql/70_frailty.sql) | [`tests/assert_frailty.sql`](../tests/assert_frailty.sql) |


## O estimador sobrevive aos dados?

### 3.1 Onda 4 — `1,0450`

Uma revisão de pipeline que arquiva o que parece morto quebra o estimador, e o viés não tem sinal.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_b0_archiving.sql`](../docs/report_b0_archiving.sql) | [`sql/80_archiving.sql`](../sql/80_archiving.sql) | [`tests/assert_archiving.sql`](../tests/assert_archiving.sql) |

### 3.2 Onda 5 — `0,8422`

Toda leitura da mesma fila imutável fica abaixo da verdade, e a defasagem cresce com a utilização.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_d1_run_length.sql`](../docs/report_d1_run_length.sql) | [`sql/90_queue.sql`](../sql/90_queue.sql) | [`tests/assert_queue.sql`](../tests/assert_queue.sql) |

### 3.3 Onda 5 — `216,6`

Um trimestre de uma mesa imutável pode ler em qualquer ponto de um fator de catorze sem que nada tenha mudado.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_e0_measurability.sql`](../docs/report_e0_measurability.sql) | [`sql/90_queue.sql`](../sql/90_queue.sql) | [`tests/assert_queue.sql`](../tests/assert_queue.sql) |


## Quem espera, e reordenar resolve?

### 4.1 Onda 5 — `2,5461`

Toda disciplina muda quem espera. Nenhuma delas muda o total ponderado por trabalho.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_c0_queue.sql`](../docs/report_c0_queue.sql) | [`sql/90_queue.sql`](../sql/90_queue.sql) | [`tests/assert_queue.sql`](../tests/assert_queue.sql) |

### 4.2 Onda 5 — `2,5540477739`

A espera total ponderada por trabalho é idêntica sob toda ordem que conserva trabalho, até a décima segunda decimal, em toda realização.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_c1_invariance.sql`](../docs/report_c1_invariance.sql) | [`sql/95_queue_closed_form.sql`](../sql/95_queue_closed_form.sql) | [`tests/assert_queue_closed_form.sql`](../tests/assert_queue_closed_form.sql) |

### 4.3 Onda 5 — `4,545`

A espera é convexa na utilização com elasticidade exatamente 1/(1-u): a 0,78, um por cento mais de demanda custa quatro e meio por cento mais de espera.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_d0_utilisation.sql`](../docs/report_d0_utilisation.sql) | [`sql/95_queue_closed_form.sql`](../sql/95_queue_closed_form.sql) | [`tests/assert_queue_closed_form.sql`](../tests/assert_queue_closed_form.sql) |

### 4.4 Onda 6 — `3,0691`

Entre as seis ordens em que três classes podem ser atendidas, a espera média reportada as ranqueia exatamente na ordem inversa do custo real.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_g0_orders.sql`](../docs/report_g0_orders.sql) | [`sql/a5_urgency.sql`](../sql/a5_urgency.sql) | [`tests/assert_urgency.sql`](../tests/assert_urgency.sql) |

### 4.5 Onda 6 — `2,4512`

A ordem que minimiza custo é urgência dividida por tempo de atendimento, e passado um limiar derivado, crítico-primeiro é a ordem errada.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_g1_handling.sql`](../docs/report_g1_handling.sql) | [`sql/a5_urgency.sql`](../sql/a5_urgency.sql) | [`tests/assert_urgency.sql`](../tests/assert_urgency.sql) |


## O rótulo é confiável?

### 5.1 Onda 6 — `49,2`

Menos da metade dos tíquetes rotulados como críticos pertence ali, e só isso custa à classe realmente crítica metade da sua espera.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_f0_triage.sql`](../docs/report_f0_triage.sql) | [`sql/a0_triage.sql`](../sql/a0_triage.sql) | [`tests/assert_triage.sql`](../tests/assert_triage.sql) |

### 5.2 Onda 6 — `0,62`

Passada certa taxa de sub-reconhecimento, o sistema de prioridade é pior para a classe crítica que nenhum sistema de prioridade.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_f1_escalation.sql`](../docs/report_f1_escalation.sql) | [`sql/a0_triage.sql`](../sql/a0_triage.sql) | [`tests/assert_triage.sql`](../tests/assert_triage.sql) |

### 5.3 Onda 7 — `0,4900`

Acurácia não é monótona no esforço: duas olhadas deixam a classe de baixo pior que uma, porque um número par de olhadas produz empates.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_h0_accuracy.sql`](../docs/report_h0_accuracy.sql) | [`sql/b0_effort.sql`](../sql/b0_effort.sql) | [`tests/assert_effort.sql`](../tests/assert_effort.sql) |

### 5.4 Onda 7 — `26,3007`

O tempo de classificação é atendido pelo mesmo servidor que o trabalho, então um sexto de dia de triagem por demanda multiplica a espera da mesma fila por dez.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_h1_effort_cost.sql`](../docs/report_h1_effort_cost.sql) | [`sql/b0_effort.sql`](../sql/b0_effort.sql) | [`tests/assert_effort.sql`](../tests/assert_effort.sql) |

### 5.5 Onda 7 — `8,9`

Quão cuidadosamente classificar não é propriedade da mesa, mas de quão cheia ela está: passada 0,89 de utilização, o esforço que vale gastar é zero.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_h2_effort_optimum.sql`](../docs/report_h2_effort_optimum.sql) | [`sql/b5_effort_sweep.sql`](../sql/b5_effort_sweep.sql) | [`tests/assert_effort.sql`](../tests/assert_effort.sql) |

### 5.6 Onda 8 — `2,0158`

A classe que mais bloqueia a fila é a classe mais cara de reconhecer, e as duas coisas se compõem.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_i0_stopping.sql`](../docs/report_i0_stopping.sql) | [`sql/c0_stopping.sql`](../sql/c0_stopping.sql) | [`tests/assert_stopping.sql`](../tests/assert_stopping.sql) |

### 5.7 Onda 8 — `1,0569`

Uma única olhada crua vence toda refinação bayesiana dela, em toda utilização, porque a refinação encolhe para uma taxa-base que é contra a classe que você não pode deixar passar.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_i1_stopping_versus_constant.sql`](../docs/report_i1_stopping_versus_constant.sql) | [`sql/c5_stopping_sweep.sql`](../sql/c5_stopping_sweep.sql) | [`tests/assert_stopping.sql`](../tests/assert_stopping.sql) |


## A mudança funcionou?

### 6.1 Onda 10 — `0,3962`

Uma mudança que mexe só num atraso não move conversão alguma, e a leitura por janela antes-e-depois a coloca no topo da página de todo jeito.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_k0_interventions.sql`](../docs/report_k0_interventions.sql) | [`sql/e0_interventions.sql`](../sql/e0_interventions.sql) | [`tests/assert_interventions.sql`](../tests/assert_interventions.sql) |

### 6.2 Onda 10 — `0,6374`

Nenhum horizonte único separa uma mudança de taxa de uma mudança de velocidade. Só a forma do ganho ao longo dos horizontes separa.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_k1_horizon.sql`](../docs/report_k1_horizon.sql) | [`sql/e5_lift_readings.sql`](../sql/e5_lift_readings.sql) | [`tests/assert_interventions.sql`](../tests/assert_interventions.sql) |

### 6.3 Onda 10 — `0,5385`

Num horizonte de vinte dias as duas mudanças que não converteram ninguém ficam em primeiro e segundo, acima da mudança que converteu mais gente.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_k2_ranking.sql`](../docs/report_k2_ranking.sql) | [`sql/e5_lift_readings.sql`](../sql/e5_lift_readings.sql) | [`tests/assert_interventions.sql`](../tests/assert_interventions.sql) |


## É a mesma população?

### 7.1 Onda 11 — `0,4544`

Toda origem ficou melhor em converter e o total ficou pior, porque a participação da melhor origem nas chegadas caiu dezoito pontos.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_m0_mix.sql`](../docs/report_m0_mix.sql) | [`sql/f0_segments.sql`](../sql/f0_segments.sql) | [`tests/assert_segments.sql`](../tests/assert_segments.sql) |

### 7.2 Onda 11 — `1,8523`

A decomposição da mudança ponderada pela média é exata. A de manual descarta um termo cruzado que vale um quinto do movimento.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_m1_decomposition.sql`](../docs/report_m1_decomposition.sql) | [`sql/f5_mix_readings.sql`](../sql/f5_mix_readings.sql) | [`tests/assert_segments.sql`](../tests/assert_segments.sql) |

### 7.3 Onda 11 — `0,0443`

Segurar a composição nas participações do primeiro período inverte o sinal da mudança reportada.

| Rode | Produzido por | Garantido por |
| --- | --- | --- |
| [`docs/report_m2_standardised.sql`](../docs/report_m2_standardised.sql) | [`sql/f5_mix_readings.sql`](../sql/f5_mix_readings.sql) | [`tests/assert_segments.sql`](../tests/assert_segments.sql) |

---

## O que não está aqui

Quatro modelos e cinco asserções não carregam achado próprio, e as duas listas são declaradas em
[`sql/g0_index.sql`](../sql/g0_index.sql) em vez de ficarem implícitas — a asserção exige que o
índice e essas duas listas particionem `sql/` e `tests/` exatamente, então um arquivo novo não pode
ser acrescentado sem ser indexado ou explicitamente dispensado.

Os modelos constroem o mundo em que todo achado é medido: os parâmetros declarados e o gerador, as
chegadas, o log monótono de eventos que três ondas posteriores usam como controle, e este índice. As
asserções garantem as convenções do próprio repositório em vez de um achado: que os parâmetros são
consistentes, que o gerador sorteia o que afirma, que toda figura citada em prosa é rederivada, que
os documentos concordam entre si, e que este índice concorda com o repositório que ele indexa.

Os vinte e um defeitos registrados estão em [`docs/ROADMAP.md`](ROADMAP.md), com a onda em que cada
um foi encontrado. Eles não são achados sobre funis — são achados sobre este repositório, e vários
deles são a coisa mais transferível que há nele.
