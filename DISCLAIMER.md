# Disclaimer

*[Português abaixo](#aviso)*

**Every number in this repository is invented.** There is no employer, client, customer, vendor or
platform data here, and none was consulted to produce it. The six funnels, their stage names, their pass
rates, their delays and the growth of their arrivals are declared parameters of a company that does not
exist, written down in [`sql/00_parameters.sql`](sql/00_parameters.sql) so that a reader can change one
and watch every published figure move.

**The funnel names are invented labels too.** `venda`, `ativacao`, `retencao`, `resgate`, `atendimento`
and `demanda` are the six generic Portuguese words for the processes a company of any size runs. They
name no real company's funnels and describe no real company's pipeline.

**The stage names are invented labels.** `lead`, `qualificado`, `proposta`, `negociacao`, `fechado`,
`contratado`, `configurado`, `primeiro-uso`, `uso-recorrente`, `ativo`, `em-risco`, `contato-feito`,
`renovado`, `perdido`, `elegivel`, `abordado`, `respondeu`, `reativado`, `aberto`, `triado`,
`em-atendimento`, `resolvido`, `confirmado`, `registrada`, `classificada`, `priorizada`, `em-execucao`
and `entregue` are generic Portuguese words chosen to read like a real funnel taxonomy. They correspond
to no real company's stage names and to no real company's process.

**The queue is invented too, including its capacity.** The three priority classes `p1`, `p2` and `p3` are
labelled `critico`, `padrao` and `melhoria`, three generic Portuguese words for priority levels; their shares, their mean handling times, the arrival rate
of 1.2 demands a day and the resulting 0.78 utilisation are declared parameters in the same file. No real
team's capacity, staffing, ticket volume or service target appears anywhere. The 60,000-demand run is not
a quarter of anything: it is the sample size the arithmetic needs, and the repository says so and then
measures what a 180-day slice would have concluded instead.

**The column no real operation has is the point.** `declared_rate` is the eventual conversion rate the
generator was built from — the answer key. A real funnel has no such column, which is exactly why a real
funnel cannot tell which of its four readings is the rate. Every finding here exists because the
repository can compare a reading against the truth, and no operation can.

**There are no market statistics, industry benchmarks or third-party figures presented as fact.** The
declared parameters are chosen to be plausible, not to be representative of anything. A conversion rate
quoted here is a property of this file, not of any market.

**Methods are cited as methods.** Cohort analysis, right-censoring, steady-state renewal arguments, the
exponential delay model, the M/G/1 queue and its priority and conservation results are standard; where a derivation is used it is written out so that it can be
checked rather than trusted.

---

# Aviso

*[English above](#disclaimer)*

**Todo número neste repositório é inventado.** Não há dado de empregador, cliente, consumidor, fornecedor
ou plataforma aqui, e nenhum foi consultado para produzi-lo. Os seis funis, seus nomes de etapa, suas
taxas de passagem, seus atrasos e o crescimento das suas entradas são parâmetros declarados de uma
empresa que não existe, escritos em [`sql/00_parameters.sql`](sql/00_parameters.sql) para que um leitor
possa mudar um deles e ver toda cifra publicada se mover.

**Os nomes dos funis também são rótulos inventados.** `venda`, `ativacao`, `retencao`, `resgate`,
`atendimento` e `demanda` são as seis palavras genéricas para processos que uma empresa de qualquer porte
opera. Não nomeiam os funis de nenhuma empresa real e não descrevem o pipeline de nenhuma empresa real.

**Os nomes de etapa são rótulos inventados.** `lead`, `qualificado`, `proposta`, `negociacao`, `fechado`,
`contratado`, `configurado`, `primeiro-uso`, `uso-recorrente`, `ativo`, `em-risco`, `contato-feito`,
`renovado`, `perdido`, `elegivel`, `abordado`, `respondeu`, `reativado`, `aberto`, `triado`,
`em-atendimento`, `resolvido`, `confirmado`, `registrada`, `classificada`, `priorizada`, `em-execucao` e
`entregue` são palavras genéricas escolhidas para ler como uma taxonomia real de funil. Não correspondem
aos nomes de etapa de nenhuma empresa real nem ao processo de nenhuma empresa real.

**A fila também é inventada, inclusive sua capacidade.** As três classes de prioridade `p1`, `p2` e `p3`
são rotuladas `critico`, `padrao` e `melhoria`, três palavras genéricas para níveis de prioridade; suas frações, seus tempos médios de atendimento, a taxa de
chegada de 1,2 demanda por dia e a utilização de 0,78 resultante são parâmetros declarados no mesmo
arquivo. Não aparece em lugar nenhum a capacidade, o quadro de pessoal, o volume de tíquetes ou a meta de
serviço de nenhum time real. A corrida de 60.000 demandas não é um trimestre de nada: é o tamanho de
amostra que a aritmética exige, e o repositório diz isso e então mede o que uma fatia de 180 dias teria
concluído.

**A coluna que nenhuma operação real tem é o ponto.** `declared_rate` é a taxa de conversão eventual a
partir da qual o gerador foi construído — o gabarito. Um funil real não tem essa coluna, e é exatamente
por isso que um funil real não consegue dizer qual das suas quatro leituras é a taxa. Todo achado aqui
existe porque o repositório pode comparar uma leitura com a verdade, e nenhuma operação pode.

**Não há estatísticas de mercado, benchmarks setoriais ou cifras de terceiros apresentadas como fato.**
Os parâmetros declarados são escolhidos para serem plausíveis, não para serem representativos de nada.
Uma taxa de conversão citada aqui é propriedade deste arquivo, não de nenhum mercado.

**Métodos são citados como métodos.** Análise de coorte, censura à direita, argumentos de renovação em
estado estacionário, o modelo de atraso exponencial, a fila M/G/1 e seus resultados de prioridade e
conservação são padrão; onde uma derivação é usada, ela está
escrita para poder ser conferida em vez de aceita.
