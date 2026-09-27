-- The index of findings, declared rather than written.
--
-- The repository is organised by wave, which is the order the work happened in and the wrong order for
-- somebody arriving with a question. This file declares the other organisation: findings grouped by the
-- question a reader shows up with, each one naming the model that produces it, the assertion that guards
-- it, the report that prints it, and one figure the build already holds to both READMEs.
--
-- It is declared here instead of written straight into a markdown file for the reason this repository
-- keeps rediscovering: a convention stated and not compiled is a convention already broken. The index in
-- docs/FINDINGS.md is checked against these rows by tests/assert_index.sql - so a report nothing points
-- at, a file that moved, a figure the build does not pin, or a wave nobody indexed all fail the build
-- rather than leaving the reader with a table of contents that used to be true.

CREATE OR REPLACE TABLE index_themes AS
SELECT * FROM (VALUES
    ('taxa',       1, 'Is the number a rate?',
                      'O número é uma taxa?'),
    ('tempo',      2, 'How long does it take?',
                      'Quanto tempo leva?'),
    ('estimador',  3, 'Does the estimator survive the data?',
                      'O estimador sobrevive aos dados?'),
    ('fila',       4, 'Who waits, and can reordering fix it?',
                      'Quem espera, e reordenar resolve?'),
    ('rotulo',     5, 'Can the label be trusted?',
                      'O rótulo é confiável?'),
    ('mudanca',    6, 'Did the change work?',
                      'A mudança funcionou?'),
    ('populacao',  7, 'Is it the same population?',
                      'É a mesma população?')
) AS t(theme, position, question_en, question_pt);

-- One row per report. The mapping is deliberately one to one: a reader who wants to see a finding should
-- be told which query prints it, and a report nobody can reach from the index is a report nobody runs.
CREATE OR REPLACE TABLE index_findings AS
SELECT * FROM (VALUES
    ('taxa', 1, 1, 'sql/30_readings.sql', 'tests/assert_mechanisms.sql', 'docs/report_10_funnels.sql', '1.9826',
     'The same six funnels read as improving or collapsing, and the only parameter that differs in kind is whether arrivals grow.',
     'Os mesmos seis funis leem como melhorando ou desabando, e o único parâmetro que difere em natureza é se as chegadas crescem.'),
    ('taxa', 2, 1, 'sql/30_readings.sql', 'tests/assert_events.sql', 'docs/report_20_stages.sql', '0.9218',
     'One funnel read four ways, stage by stage. The four disagree, and only one of them is the conversion rate.',
     'Um funil lido de quatro maneiras, estágio por estágio. As quatro discordam, e só uma delas é a taxa de conversão.'),
    ('taxa', 3, 1, 'sql/40_closed_form.sql', 'tests/assert_mechanisms.sql', 'docs/report_30_mechanisms.sql', '1.4161',
     'Move the arrival growth and hold the delay: the cohort reading does not move at all.',
     'Mexa no crescimento das chegadas e segure o atraso: a leitura por coorte não se move nem um pouco.'),
    ('taxa', 4, 1, 'sql/40_closed_form.sql', 'tests/assert_closed_form.sql', 'docs/report_40_delay.sql', '1.0825',
     'Move the delay and hold arrivals flat: the dashboard reading sits on the eventual rate while the cohort reading falls away from it.',
     'Mexa no atraso e segure as chegadas planas: a leitura de painel fica sobre a taxa eventual enquanto a de coorte se afasta dela.'),
    ('taxa', 5, 1, 'sql/30_readings.sql', 'tests/assert_events.sql', 'docs/report_50_ceiling.sql', '2.3787',
     'Six stages read above the product of their own pass rates, which is a bound a rate cannot exceed.',
     'Seis estágios leem acima do produto das próprias taxas de passagem, que é um limite que uma taxa não pode exceder.'),
    ('taxa', 6, 9, 'sql/d5_movement_readings.sql', 'tests/assert_movements.sql', 'docs/report_j1_ceiling_breach.sql', '1.1762',
     'And that bound stops being a bound the moment a stage can be skipped: a healthy funnel breaches it by a sixth.',
     'E esse limite deixa de ser limite no instante em que um estágio pode ser pulado: um funil saudável o viola por um sexto.'),
    ('taxa', 7, 9, 'sql/d5_movement_readings.sql', 'tests/assert_movements.sql', 'docs/report_j2_denominators.sql', '1.0812',
     'Counting rows instead of subjects biases the same report in both directions at once, so there is no factor to divide by.',
     'Contar linhas em vez de sujeitos enviesa o mesmo relatório nas duas direções ao mesmo tempo, então não existe fator por que dividir.'),
    ('taxa', 8, 9, 'sql/d0_movements.sql', 'tests/assert_movements.sql', 'docs/report_j0_movements.sql', '1.2670',
     'One row per subject per stage is not a storage choice: the messy log is a quarter larger on the same population.',
     'Uma linha por sujeito por estágio não é escolha de armazenamento: o log confuso é um quarto maior na mesma população.'),

    ('tempo', 1, 2, 'sql/50_velocity.sql', 'tests/assert_velocity.sql', 'docs/report_60_velocity.sql', '0.818',
     'The measured speed ranks the funnels differently from their actual speed, and the inversion is at the top.',
     'A velocidade medida ranqueia os funis de forma diferente da velocidade real, e a inversão está no topo.'),
    ('tempo', 2, 2, 'sql/50_velocity.sql', 'tests/assert_velocity.sql', 'docs/report_70_velocity_growth.sql', '5.77',
     'There is no arrival growth rate at which the naive time reading is correct, unlike the rate reading, which is exact at flat arrivals.',
     'Não existe taxa de crescimento de chegadas em que a leitura ingênua de tempo esteja correta, ao contrário da leitura de taxa, exata com chegadas planas.'),
    ('tempo', 3, 3, 'sql/60_survival.sql', 'tests/assert_survival.sql', 'docs/report_90_timing.sql', '19.911',
     'The median time to a stage usually does not exist, because fewer than half the subjects ever arrive there.',
     'O tempo mediano até um estágio geralmente não existe, porque menos da metade dos sujeitos chega lá.'),
    ('tempo', 4, 3, 'sql/60_survival.sql', 'tests/assert_survival.sql', 'docs/report_80_survival.sql', '29.8',
     'The product-limit estimator gives the cohort reading''s answer without discarding a third of the subjects, and with a tighter interval.',
     'O estimador produto-limite dá a resposta da leitura por coorte sem descartar um terço dos sujeitos, e com intervalo mais estreito.'),
    ('tempo', 5, 4, 'sql/70_frailty.sql', 'tests/assert_frailty.sql', 'docs/report_a0_frailty.sql', '0.8439',
     'Extra spread alone makes the measured speed faster, at a true mean that has not moved.',
     'Só o acréscimo de dispersão deixa a velocidade medida mais rápida, com a média verdadeira parada.'),

    ('estimador', 1, 4, 'sql/80_archiving.sql', 'tests/assert_archiving.sql', 'docs/report_b0_archiving.sql', '1.0450',
     'A pipeline review that archives what looks dead breaks the estimator, and the bias has no sign.',
     'Uma revisão de pipeline que arquiva o que parece morto quebra o estimador, e o viés não tem sinal.'),
    ('estimador', 2, 5, 'sql/90_queue.sql', 'tests/assert_queue.sql', 'docs/report_d1_run_length.sql', '0.8422',
     'Every reading of the same unchanging queue is below the truth, and the shortfall grows with utilisation.',
     'Toda leitura da mesma fila imutável fica abaixo da verdade, e a defasagem cresce com a utilização.'),
    ('estimador', 3, 5, 'sql/90_queue.sql', 'tests/assert_queue.sql', 'docs/report_e0_measurability.sql', '216.6',
     'One quarter of an unchanging desk can read anywhere across a factor of fourteen with nothing having changed.',
     'Um trimestre de uma mesa imutável pode ler em qualquer ponto de um fator de catorze sem que nada tenha mudado.'),

    ('fila', 1, 5, 'sql/90_queue.sql', 'tests/assert_queue.sql', 'docs/report_c0_queue.sql', '2.5461',
     'Every discipline moves who waits. None of them moves the work-weighted total.',
     'Toda disciplina muda quem espera. Nenhuma delas muda o total ponderado por trabalho.'),
    ('fila', 2, 5, 'sql/95_queue_closed_form.sql', 'tests/assert_queue_closed_form.sql', 'docs/report_c1_invariance.sql', '2.5540477739',
     'The work-weighted total waiting is identical under every work-conserving order, to twelve decimal places, in every realisation.',
     'A espera total ponderada por trabalho é idêntica sob toda ordem que conserva trabalho, até a décima segunda decimal, em toda realização.'),
    ('fila', 3, 5, 'sql/95_queue_closed_form.sql', 'tests/assert_queue_closed_form.sql', 'docs/report_d0_utilisation.sql', '4.545',
     'Waiting is convex in utilisation with elasticity exactly 1/(1-u): at 0.78, one percent more demand costs four and a half percent more waiting.',
     'A espera é convexa na utilização com elasticidade exatamente 1/(1-u): a 0,78, um por cento mais de demanda custa quatro e meio por cento mais de espera.'),
    ('fila', 4, 6, 'sql/a5_urgency.sql', 'tests/assert_urgency.sql', 'docs/report_g0_orders.sql', '3.0691',
     'Across all six orders three classes can be served in, the reported mean wait ranks them in exactly reverse order of their true cost.',
     'Entre as seis ordens em que três classes podem ser atendidas, a espera média reportada as ranqueia exatamente na ordem inversa do custo real.'),
    ('fila', 5, 6, 'sql/a5_urgency.sql', 'tests/assert_urgency.sql', 'docs/report_g1_handling.sql', '2.4512',
     'The order that minimises cost is urgency divided by handling time, and past a derived threshold critical-first is the wrong order.',
     'A ordem que minimiza custo é urgência dividida por tempo de atendimento, e passado um limiar derivado, crítico-primeiro é a ordem errada.'),

    ('rotulo', 1, 6, 'sql/a0_triage.sql', 'tests/assert_triage.sql', 'docs/report_f0_triage.sql', '49.2',
     'Fewer than half the tickets labelled critical belong there, and that alone costs the genuinely critical class half of its waiting.',
     'Menos da metade dos tíquetes rotulados como críticos pertence ali, e só isso custa à classe realmente crítica metade da sua espera.'),
    ('rotulo', 2, 6, 'sql/a0_triage.sql', 'tests/assert_triage.sql', 'docs/report_f1_escalation.sql', '0.62',
     'Past a certain rate of under-recognition the priority system is worse for the critical class than no priority system at all.',
     'Passada certa taxa de sub-reconhecimento, o sistema de prioridade é pior para a classe crítica que nenhum sistema de prioridade.'),
    ('rotulo', 3, 7, 'sql/b0_effort.sql', 'tests/assert_effort.sql', 'docs/report_h0_accuracy.sql', '0.4900',
     'Accuracy is not monotone in effort: two looks leave the bottom class worse than one, because an even number of looks produces ties.',
     'Acurácia não é monótona no esforço: duas olhadas deixam a classe de baixo pior que uma, porque um número par de olhadas produz empates.'),
    ('rotulo', 4, 7, 'sql/b0_effort.sql', 'tests/assert_effort.sql', 'docs/report_h1_effort_cost.sql', '26.3007',
     'Classification time is served by the same server as the work, so a sixth of a day of triage per demand multiplies the same queue''s waiting by ten.',
     'O tempo de classificação é atendido pelo mesmo servidor que o trabalho, então um sexto de dia de triagem por demanda multiplica a espera da mesma fila por dez.'),
    ('rotulo', 5, 7, 'sql/b5_effort_sweep.sql', 'tests/assert_effort.sql', 'docs/report_h2_effort_optimum.sql', '8.9',
     'How carefully to classify is not a property of the desk but of how full it is: past 0.89 utilisation the effort worth spending is zero.',
     'Quão cuidadosamente classificar não é propriedade da mesa, mas de quão cheia ela está: passada 0,89 de utilização, o esforço que vale gastar é zero.'),
    ('rotulo', 6, 8, 'sql/c0_stopping.sql', 'tests/assert_stopping.sql', 'docs/report_i0_stopping.sql', '2.0158',
     'The class that blocks the queue most is the class most expensive to recognise, and the two compound.',
     'A classe que mais bloqueia a fila é a classe mais cara de reconhecer, e as duas coisas se compõem.'),
    ('rotulo', 7, 8, 'sql/c5_stopping_sweep.sql', 'tests/assert_stopping.sql', 'docs/report_i1_stopping_versus_constant.sql', '1.0569',
     'A single raw look beats every Bayesian refinement of it, at every utilisation, because the refinement shrinks toward a base rate that is against the class you cannot afford to miss.',
     'Uma única olhada crua vence toda refinação bayesiana dela, em toda utilização, porque a refinação encolhe para uma taxa-base que é contra a classe que você não pode deixar passar.'),

    ('mudanca', 1, 10, 'sql/e0_interventions.sql', 'tests/assert_interventions.sql', 'docs/report_k0_interventions.sql', '0.3962',
     'A change that moves only a delay moves no conversion at all, and the before-and-after window reading puts it top of the page anyway.',
     'Uma mudança que mexe só num atraso não move conversão alguma, e a leitura por janela antes-e-depois a coloca no topo da página de todo jeito.'),
    ('mudanca', 2, 10, 'sql/e5_lift_readings.sql', 'tests/assert_interventions.sql', 'docs/report_k1_horizon.sql', '0.6374',
     'No single horizon separates a rate change from a speed change. Only the shape of the lift across horizons does.',
     'Nenhum horizonte único separa uma mudança de taxa de uma mudança de velocidade. Só a forma do ganho ao longo dos horizontes separa.'),
    ('mudanca', 3, 10, 'sql/e5_lift_readings.sql', 'tests/assert_interventions.sql', 'docs/report_k2_ranking.sql', '0.5385',
     'At a twenty-day horizon the two changes that converted nobody rank first and second, above the change that converted the most people.',
     'Num horizonte de vinte dias as duas mudanças que não converteram ninguém ficam em primeiro e segundo, acima da mudança que converteu mais gente.'),

    ('populacao', 1, 11, 'sql/f0_segments.sql', 'tests/assert_segments.sql', 'docs/report_m0_mix.sql', '0.4544',
     'Every origin got better at converting and the total got worse, because the best origin''s share of arrivals fell eighteen points.',
     'Toda origem ficou melhor em converter e o total ficou pior, porque a participação da melhor origem nas chegadas caiu dezoito pontos.'),
    ('populacao', 2, 11, 'sql/f5_mix_readings.sql', 'tests/assert_segments.sql', 'docs/report_m1_decomposition.sql', '1.8523',
     'The mean-weighted decomposition of the change is exact. The textbook one drops a cross term worth a fifth of the movement.',
     'A decomposição da mudança ponderada pela média é exata. A de manual descarta um termo cruzado que vale um quinto do movimento.'),
    ('populacao', 3, 11, 'sql/f5_mix_readings.sql', 'tests/assert_segments.sql', 'docs/report_m2_standardised.sql', '0.0443',
     'Holding the composition at the first period''s shares flips the sign of the reported change.',
     'Segurar a composição nas participações do primeiro período inverte o sinal da mudança reportada.')
) AS t(theme, position, wave, model_file, assertion_file, report_file, figure, claim_en, claim_pt);

-- The two exemptions from index coverage, declared so that they are auditable rather than implicit.
--
-- A model that produces no finding of its own and an assertion that guards no finding of its own are both
-- legitimate - the first builds the world every finding is measured in, the second guards the
-- repository's own conventions. What is not legitimate is leaving them out of the index silently, so
-- they are named here and tests/assert_index.sql requires the two lists plus the index to partition the
-- directories exactly.
CREATE OR REPLACE TABLE index_foundation AS
SELECT * FROM (VALUES
    ('sql/00_parameters.sql', 'Every declared number, and the generator written in arithmetic.'),
    ('sql/10_subjects.sql',   'Arrivals per funnel per day, which every later wave measures on.'),
    ('sql/20_events.sql',     'The monotone event log three later waves use as their control world.'),
    ('sql/g0_index.sql',      'This index itself.')
) AS t(model_file, note);

CREATE OR REPLACE TABLE index_discipline AS
SELECT * FROM (VALUES
    ('tests/assert_parameters.sql',        'The declared parameters are internally consistent.'),
    ('tests/assert_generator.sql',         'The generator draws the distributions it claims to.'),
    ('tests/assert_published_figures.sql', 'Every figure quoted in prose is re-derived from the models.'),
    ('tests/assert_documents.sql',         'The documents agree with each other and with the repository.'),
    ('tests/assert_index.sql',             'The index agrees with the repository it indexes.')
) AS t(assertion_file, note);
