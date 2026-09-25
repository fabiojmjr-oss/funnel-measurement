# O funil que toda empresa desenha, e a aritmética que diz que ele não é uma taxa

*[English](README.md)*

**Taxa de conversão de funil é quase sempre calculada dividindo dois números que pertencem a pessoas
diferentes.** Conte quantos entraram na etapa um neste mês, conte quantos chegaram à etapa cinco neste
mês, divida. Quem chegou à etapa cinco neste mês entrou no funil dois meses atrás. A razão não é taxa de
conversão de nada — é a forma das entradas dividida por ela mesma, defasada.

Este repositório constrói seis funis que uma empresa madura opera, lê cada um de quatro maneiras, e
mostra que a leitura do painel **não está enviesada numa direção conhecível**. Ela é a soma de dois erros
de sinais opostos, e qual deles vence depende de a demanda estar subindo ou caindo e de quanto tempo o
funil leva. Em um dos seis ela marca **1,98 vez** a taxa real de conversão. Em outro marca **0,92 vez**.
Mesmo motor, mesmo comportamento, nenhum bug.

Tudo aqui é **SQL**. Dezessete arquivos de modelo, dezessete de asserção, um Makefile que decide a ordem, e nenhuma
segunda linguagem: uma asserção é uma consulta que devolve as linhas que a quebram, então zero linhas é
aprovação e o arcabouço não precisa de framework de teste. Todo número nos documentos abaixo é
re-derivado por `tests/assert_published_figures.sql`, então uma mudança que mova uma cifra publicada
quebra o build em vez de deixar o texto silenciosamente errado.

Nenhum dado de empregador, cliente, consumidor ou fornecedor aparece em qualquer parte — ver
[`DISCLAIMER.md`](DISCLAIMER.md).

## Os seis funis

Declarados em [`sql/00_parameters.sql`](sql/00_parameters.sql), cada número deles. **47.317** sujeitos ao
longo de 180 dias produzem **144.858** eventos de etapa, dos quais 137.923 já aconteceram no dia em que o
relatório roda.

| Funil | Etapas | Entradas |
| --- | --- | --- |
| `venda` | lead → qualificado → proposta → negociacao → fechado | crescendo 1,2%/dia |
| `ativacao` | contratado → configurado → primeiro-uso → uso-recorrente | crescendo 0,8%/dia |
| `retencao` | ativo → em-risco → contato-feito → renovado | estável |
| `resgate` (de churn) | perdido → elegivel → abordado → respondeu → reativado | caindo 0,9%/dia |
| `atendimento` | aberto → triado → em-atendimento → resolvido → confirmado | crescendo 0,3%/dia |
| `demanda` (tratamento e prioridade) | registrada → classificada → priorizada → em-execucao → entregue | crescendo 2,0%/dia |

O crescimento das entradas não é decoração. É o parâmetro que decide o quanto o painel está errado, e é o
único parâmetro que um relatório de funil nunca menciona.

## O achado, numa tabela

Cada funil na sua última etapa. `painel` é a leitura por janela descrita acima; `coorte` é a parcela de
uma coorte velha o suficiente para ter tido sua chance; `teto` é a taxa eventual declarada, o máximo que
o funil pode entregar algum dia.

| Funil | Entradas | `painel` | `coorte` | `teto` | painel ÷ coorte |
| --- | --- | --- | --- | --- | --- |
| `resgate` | **−0,9%/dia** | 0,0743 | **0,0375** | 0,0602 | **1,9826** |
| `retencao` | estável | 0,1080 | 0,0636 | 0,1107 | **1,6988** |
| `atendimento` | +0,3%/dia | 0,4537 | 0,4764 | 0,4730 | 0,9522 |
| `ativacao` | +0,8%/dia | 0,2571 | 0,2595 | 0,2991 | 0,9907 |
| `venda` | +1,2%/dia | 0,0541 | 0,0587 | 0,0737 | 0,9218 |
| `demanda` | **+2,0%/dia** | 0,2198 | 0,2308 | 0,3529 | 0,9524 |

**O erro não tem sinal.** Dois funis leem alto, quatro leem baixo, e a razão vai de 0,9218 a 1,9826. Um
gestor não consegue carregar uma correção mental, porque a correção troca de sinal com o crescimento do
próprio pipeline dele.

E no `resgate` o painel excede o teto em **todas as etapas**:

| Etapa | `painel` | `teto` | Vezes acima de uma taxa que não pode exceder |
| --- | --- | --- | --- |
| respondeu | 0,2079 | 0,1468 | **1,4161** |
| abordado | 0,6683 | 0,5063 | 1,3200 |
| reativado | 0,0743 | 0,0602 | 1,2335 |
| elegivel | 0,7426 | 0,6100 | 1,2173 |

Seis etapas na conta leem acima do seu teto; quatro delas — todas no `resgate` — por mais do que o ruído
de amostragem permite. **Uma taxa de conversão maior que a taxa máxima de conversão alcançável não é uma
taxa de conversão**, e isso não é discussão de definição, é aritmética.

## Por quê: dois erros, puxando em sentidos opostos

A etapa dois de todo funil é o caso em que a álgebra fecha — o sujeito chega lá após um único atraso
exponencial — então as duas leituras têm forma fechada, e a simulação é conferida contra ela em vez de
contra si mesma. O maior dos doze desvios é de **2,04** erros padrão da
derivação ([`tests/assert_closed_form.sql`](tests/assert_closed_form.sql)).

**A leitura por coorte não tem termo de crescimento.** `coorte = p · (1 − e^(−W/m))` para taxa de
passagem `p`, atraso médio `m` e janela de maturidade `W`. Uma coorte é lida numa idade fixa, então a
forma das entradas se cancela. Essa propriedade é o que a torna uma taxa, e está afirmada como
identidade.

**A leitura do painel é um estimador de estado estacionário da quantidade errada.** Mantenha as entradas
estáveis e ela converge **exatamente** para a taxa eventual `p` — para qualquer atraso, com nove casas
decimais, que é [`tests/assert_mechanisms.sql`](tests/assert_mechanisms.sql). Ela não é ruidosa e não é
enviesada sobre `p`. Ela está respondendo *"que parcela converte eventualmente?"* quando a pergunta feita
foi *"que parcela converte dentro do mês pelo qual estou sendo medido?"*

| Atraso médio | `painel` | `teto` | `coorte` (30 dias) | razão |
| --- | --- | --- | --- | --- |
| 1 dia | 0,4500 | 0,4500 | 0,4500 | 1,0000 |
| 10 dias | 0,4500 | 0,4500 | 0,4276 | 1,0524 |
| 30 dias | 0,4481 | 0,4500 | **0,2845** | **1,5754** |
| 60 dias | 0,4212 | 0,4500 | **0,1771** | **2,3787** |

A coluna do painel quase não se move; a da coorte cai pela metade. A diferença entre as duas é **o tempo
que o funil leva**, e um funil lento reportado assim parece rápido.

**E então o crescimento quebra até isso.** Mantenha o atraso fixo e mova só as entradas:

| Entradas | `painel` | `coorte` | razão |
| --- | --- | --- | --- |
| −3%/dia | 0,4871 | 0,4500 | **1,0825** |
| estável | 0,4500 | 0,4500 | 1,0000 |
| +3%/dia | 0,4181 | 0,4500 | **0,9292** |

Monótono nos sessenta e um pontos da varredura, cruzando um exatamente no crescimento zero. Mesmo funil,
mesmo comportamento: o painel marca **1,1651 vez** mais alto a −3% ao dia do que a +3%, comprado apenas
pela direção da demanda. Um
pipeline que está enchendo reporta uma taxa de conversão que está caindo, e o trimestre em que ele
finalmente para de crescer é o trimestre em que a taxa parece se recuperar.

No `resgate` os dois erros apontam para o mesmo lado — as entradas estão caindo *e* o funil leva 29 dias
contra uma janela de 30 — e é assim que um número chega a 1,9826.

## E a mesma censura, na dimensão do tempo

A onda 1 perguntou que parcela dos sujeitos chega a uma etapa. A outra metade de uma revisão de funil é
quanto tempo eles levam, e os mesmos sujeitos estão faltando nessa média: **os que ainda não chegaram à
etapa são os lentos.** Um tempo médio até a etapa calculado sobre as conversões de uma tabela de eventos
é uma média sobre os sobreviventes de uma corrida ainda em andamento.

| Funil | Entradas | Leva de fato | Lê como | lê ÷ real | Restrito (30d) | É o mais lento | **Lê como mais lento** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `retencao` | estável | **30,0 d** | 26,82 | 0,894 | 29,15 | **1º** | 2º |
| `resgate` | −0,9%/dia | 29,0 d | **29,07** | **1,002** | 29,64 | 2º | **1º** |
| `demanda` | +2,0%/dia | 27,0 d | 22,09 | **0,818** | 27,01 | 3º | 3º |
| `venda` | +1,2%/dia | 23,0 d | 20,08 | 0,873 | 29,24 | 4º | 4º |
| `ativacao` | +0,8%/dia | 19,0 d | 17,55 | 0,924 | 26,12 | 5º | 5º |
| `atendimento` | +0,3%/dia | 5,2 d | 5,01 | 0,964 | 18,13 | 6º | 6º |

**O ranking inverte no topo.** O `retencao` é o funil mais lento da conta e lê como o segundo mais
lento; o `resgate` é o segundo mais lento e lê como o mais lento. Nada do comportamento de nenhum dos
dois está envolvido: as entradas do `resgate` estão *caindo*, então suas conversões observadas vêm quase
inteiramente de coortes antigas e plenamente maduras, e sua leitura quase não é censurada — **1,002** da
verdade. As entradas estáveis do `retencao` ainda carregam coortes jovens, então seus casos lentos ainda
estão em curso. O funil medido com mais honestidade é aquele cuja demanda está morrendo.

**E, diferente da taxa, a leitura de tempo não tem taxa de crescimento na qual esteja certa.** A taxa do
painel da onda 1 cai exatamente sobre a taxa eventual quando as entradas estão estáveis. Mantenha um
atraso de vinte dias e varra as entradas, e a leitura de tempo é rápida *em todo ponto*:

| Entradas | Leva de fato | Lê como | lê ÷ real |
| --- | --- | --- | --- |
| −3%/dia | 20,0 d | 19,714 | 0,9857 |
| estável | 20,0 d | 17,511 | **0,8756** |
| +3%/dia | 20,0 d | **12,514** | **0,6257** |

Com entradas estáveis ainda é 12% rápida, porque as coortes jovens existem independentemente de estarem
crescendo. A +3% ao dia o funil reporta **37% mais rápido do que é**. Monótono nos sessenta e um pontos,
e não há ponto fixo para mirar.

**A medida que não exige premissa nenhuma não é uma duração.** O `restrito` acima é
`média(mín(tempo, 30 dias))` sobre cada sujeito de uma coorte madura, contando a 30 quem não havia
convertido até o dia 30. É definida para todos, não exige nada a ser assumido sobre os não convertidos, e
sua forma fechada é `(1 − p)·W + p·m·(1 − e^(−W/m))` — mas veja o que ela faz com o `atendimento`: o
funil mais rápido da conta por um fator de **5,77** lê só **1,61** vez mais rápido que o mais lento,
porque 52,7% dos seus sujeitos nunca chegam a `confirmado` e são contados na borda da janela. A medida
mistura duração com conclusão por construção.

Então o relatório honesto é um **par, não um número**: a média restrita ao lado da taxa de coorte da onda
1. Cada uma sozinha pode ser movida pela outra, e nenhuma está identificada sem a outra.

As duas leituras de tempo fecham algebricamente na etapa dois — a média truncada
`m − W·e^(−W/m)/(1 − e^(−W/m))` e a média restrita acima — e o maior dos doze desvios é de **1,11** erro
padrão, com a tolerância calculada da própria dispersão da simulação em vez de de uma binomial, porque
estas são médias.

## E o estimador que não precisa nem do descarte nem da premissa

As ondas 1 e 2 diagnosticaram a mesma coisa duas vezes, e a prescrição da onda 1 — ler coortes velhas o
bastante para terem terminado — está correta e é caro. Ela se recusa a olhar qualquer coorte mais nova que
a janela de maturidade, o que nesta conta são **14.093 de 47.317 sujeitos, 29,8%**. E a parcela cresce com
a taxa de crescimento: a leitura custa mais dados exatamente onde o negócio se move mais rápido.

O estimador produto-limite de Kaplan e Meier não descarta nada. Cada sujeito contribui pelo tempo em que
foi observado e depois sai do conjunto de risco — um sujeito que entrou há quatro dias diz ao estimador o
que aconteceu em quatro dias e se cala sobre o quinto. A curva é um produto acumulado sobre o conjunto de
risco em cada tempo de evento, que é uma window function sobre uma tabela ordenada: o
`sql/60_survival.sql` é uma consulta, e também não precisou de segunda linguagem.

| Funil | `painel` | `coorte` | **Kaplan–Meier** | `verdade` | erro KM | erro coorte | razão |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `venda` qualificado | 0,4267 | 0,4464 | **0,4453** | 0,4500 | 0,00580 | 0,00699 | **0,8302** |
| `ativacao` configurado | 0,7820 | 0,7782 | 0,7833 | 0,7800 | 0,00670 | 0,00770 | 0,8701 |
| `retencao` em-risco | 0,2107 | 0,1656 | 0,1661 | 0,2200 | 0,00575 | 0,00605 | 0,9506 |
| `resgate` elegivel | 0,7426 | 0,5807 | 0,5820 | 0,6100 | 0,00966 | 0,00990 | 0,9756 |
| `atendimento` triado | 0,9553 | 0,9583 | 0,9582 | 0,9600 | 0,00167 | 0,00187 | 0,8953 |
| `demanda` classificada | 0,9101 | 0,9420 | 0,9408 | 0,9400 | 0,00207 | 0,00269 | **0,7698** |

**Mesma resposta, intervalo mais estreito, nas vinte e duas etapas.** A razão entre erros padrão vai de
**0,7698** a 0,9809 e nunca alcança um, o que em termos de tamanho de amostra é **1,24 vez os dados** em
média e **1,688 vez** na `demanda` — o funil que cresce mais rápido, e portanto aquele cujas coortes
jovens a leitura de coorte estava jogando fora. Três formas fechadas são verificadas na etapa dois: a
incidência `p·(1 − e^(−W/m))` a menos de **1,05** erro padrão, o platô contra `p`, e a meia-vida contra
`m·ln 2` a menos de 2,82%.

**E o tempo mediano até uma etapa geralmente não existe.** Uma mediana precisa que mais da metade dos
sujeitos chegue lá, e nesta conta **quatorze das vinte e duas etapas** nunca chegam:

| Etapa | Convertem eventualmente | **Meia-vida** | Mediana |
| --- | --- | --- | --- |
| `atendimento` triado | 0,9582 | 0,139 d | 0,15 d |
| `demanda` priorizada | 0,6817 | 3,183 d | 5,17 d |
| `resgate` abordado | **0,4992** | 13,257 d | **nenhuma** |
| `venda` fechado | 0,0723 | **19,911 d** | **nenhuma** |
| `retencao` renovado | 0,1047 | 24,231 d | **nenhuma** |

O `resgate` abordado deixa de ter mediana por **oito milésimos** de taxa de conversão. Então um relatório
que cita "tempo mediano até fechar" para uma etapa que 7% dos sujeitos alcançam calculou outra coisa —
quase sempre a mediana entre os que chegaram, que é uma população diferente a cada mês.

A quantidade sempre definida é a **meia-vida**: o dia em que metade das conversões *eventuais* já
aconteceu. Sua forma fechada é `m·ln 2`, que não contém `p` nenhum — então é a única medida de velocidade
aqui que não pode ser movida por uma mudança em quantos convertem. Reporte-a ao lado do platô e as duas
ficam identificadas; reporte qualquer uma sozinha e a outra a move.

**A limitação é a única premissa que o estimador de fato faz.** A censura tem de ser independente de
quando o sujeito teria convertido. Aqui ela é, por construção: a única coisa censurando alguém é o
calendário. Num funil real frequentemente não é — registros são arquivados, casos lentos recebem marca de
"perdido", uma revisão de pipeline fecha o que parece parado — e cada um desses censura os sujeitos lentos
*porque* são lentos, que é a única coisa que quebra este estimador e não pode ser detectada de dentro
dele.

## E a única premissa que o estimador faz, quebrada de propósito

A onda 3 terminou numa ressalva: o estimador produto-limite exige censura independente de quando o sujeito
teria convertido, e um funil real quebra isso primeiro. Quebrar exige dois passos, e o primeiro é um achado
por si só.

**Um atraso exponencial não pode ser quebrado por arquivamento, e é por isso que a exponencial teve de
sair.** Sob uma exponencial, um sujeito aberto há vinte dias tem exatamente a mesma chance de converter
amanhã que um aberto hoje de manhã, então remover uma parcela dos lentos não remove nada de que o
estimador precisava: os sobreviventes têm o mesmo futuro que os retirados. Uma primeira tentativa desta
onda arquivou todo registro parado com uma única probabilidade e não produziu viés algum — corretamente,
porque uma taxa de censura que depende só do tempo decorrido é exatamente o que o método permite.

Então o `sql/70_frailty.sql` divide a conta em duas classes declaradas — **30% lentos a 2,5× o atraso, 70%
rápidos a 0,357143×** — calibradas para que o multiplicador médio seja **exatamente 1**. O funil é, na
média, tão rápido quanto era nas ondas 1 a 3; só a dispersão muda. O estimador continua certo: conferido
contra a forma fechada da mistura de duas exponenciais, o maior desvio é de **1,38** erro padrão.

**Mas a dispersão sozinha faz a velocidade medida parecer maior, com a média verdadeira parada.**

| Funil | Uma exponencial | Duas classes | razão |
| --- | --- | --- | --- |
| `retencao` | 17,2008 d | **14,5152 d** | **0,8439** |
| `resgate` | 9,7738 d | 8,8153 d | 0,9019 |
| `venda` | 1,9540 d | 1,8483 d | 0,9459 |
| `atendimento` | 0,2006 d | 0,2016 d | 1,0047 |

A heterogeneidade empurra mais da classe lenta para além do horizonte onde ninguém a vê, então a leitura
ingênua de tempo da onda 2 perde outros **15,6%** no `retencao` sem mudança alguma na velocidade média. A
onda 2 assumiu uma exponencial e portanto **subestimou o próprio achado**.

**Depois a revisão quebra o estimador, porque revisão é julgamento e não cronômetro.** Alguém abre o
registro, pergunta ao responsável pela conta, e fecha os que estão de fato mortos — e esse julgamento
correlaciona com a classe, que é o que os tornou lentos. Na janela declarada de 21 dias a revisão fecha
**9.541** registros, dos quais **75,55%** são da classe lenta contra **29,87%** da população: ela é
**2,529 vezes** mais propensa a fechar um registro lento. Nada nos dados registra a classe, e é por isso
que nada disso é visível de dentro: o analista vê uma censura e não consegue distingui-la do calendário.

| Janela da revisão | `retencao` (classe lenta 50 d) | `venda` (classe lenta 5 d) |
| --- | --- | --- |
| 3 dias | **1,0450** | **0,9372** |
| 7 dias | 1,0276 | 0,9700 |
| 14 dias | 1,0036 | 0,9932 |
| 21 dias | 1,0082 | 0,9986 |
| **30 dias** | **1,0000** | **1,0000** |
| 60 dias | 1,0000 | 1,0000 |

Duas coisas nessa tabela, e a segunda é a útil.

**O viés não tem sinal.** O `retencao` lê alto e o `venda` lê baixo, da mesma revisão, na mesma janela.
Dois efeitos brigam: arquivar esconde conversões que teriam ocorrido, o que empurra a estimativa para
*baixo*; e remove cedo do conjunto de risco sujeitos que nunca iriam converter, o que empurra o hazard
estimado para *cima*. Qual vence depende da taxa de passagem e do atraso da classe lenta contra a janela —
dois parâmetros, não um. Na varredura a razão vai de **0,9372 a 1,0450**, sete pontos acima de um e vinte e
três abaixo, e o `resgate` troca de sinal *dentro* da própria varredura. Nem a magnitude é monótona: o
`retencao` lê 1,0036 em quatorze dias e volta a 1,0082 em vinte e um.

**E existe uma condição exata em que isso não pode acontecer.** Todos os dezoito pontos da varredura cuja
janela de revisão está no horizonte reportado ou além dele são não viesados com precisão de máquina —
porque uma revisão que não remove ninguém antes do dia 30 não pode tocar uma estimativa feita no dia 30.
Dentro do horizonte, só seis de trinta e seis pontos são. Então a regra é nítida e barata de conferir:

> **Uma revisão de pipeline cuja janela é mais curta que o horizonte que você reporta contamina o
> relatório. Uma no horizonte ou além dele não pode.**

É toda a prescrição, e ela não precisa de estatística para ser aplicada — só que alguém compare dois
números que hoje moram em documentos diferentes: quanto tempo um registro fica parado antes de a revisão
fechá-lo, e quantos dias o relatório de conversão cobre.

## E o funil que não é funil nenhum: a fila dentro de `demanda`

Toda onda acima trata de uma *leitura* errada. Esta não. `demanda` tem uma etapa chamada `priorizada`, e
nada numa taxa de passagem ou num atraso contém o fato que torna priorizar uma decisão: **o time trabalha
numa demanda por vez, então colocar este item em primeiro coloca outro item em segundo.** Um atraso não é
propriedade da demanda. É, em boa parte, o tempo que a demanda passa atrás de outras demandas.

Então [`sql/90_queue.sql`](sql/90_queue.sql) troca o atraso de uma etapa por um servidor. Um servidor, três
classes declaradas — 10% `critico` com 1,25 dia de atendimento, 30% `padrao` com 0,75, 60% `melhoria` com
0,50 — chegando por Poisson a 1,2 por dia, o que deixa o servidor ocupado **0,78** do tempo. Isso é M/G/1
com prioridade não preemptiva, escolhido porque seu tempo médio de espera é conhecido no papel para cada
classe sob qualquer ordem de prioridade, de modo que toda figura abaixo é conferida contra aritmética feita
separadamente.

Três ordens são comparadas: primeiro a chegar primeiro a ser servido, `priority` (crítico primeiro) e
`reversed` — que não é espantalho, porque limpar os itens rápidos para fazer a contagem de backlog cair é o
que times de fato fazem sob pressão, e `melhoria` é ao mesmo tempo a classe menos urgente e a mais barata
de servir.

| Ordem | `critico` | `padrao` | `melhoria` | **espera média por demanda** |
| --- | --- | --- | --- | --- |
| primeiro a chegar | 2,5461 d | 2,5624 d | 2,5632 d | **2,5612 d** |
| `priority` | **0,6961 d** | 1,1636 d | **4,3583 d** | **3,0358 d** (1,1853×) |
| `reversed` | **6,7375 d** | 2,3953 d | **0,9051 d** | **1,9382 d** (0,7568×) |

Cada um desses nove números cai sobre sua forma fechada — a fórmula de Cobham para as ordens de prioridade,
a de Pollaczek e Khinchine para primeiro a chegar — sendo o pior desvio de **1,293** erro padrão. As
derivações são 0,6705, 1,1473 e 4,4261 dias sob `priority`, 6,9737, 2,4147 e 0,8957 sob `reversed`, e
2,5868 para as três classes sob primeiro a chegar, que não sabe que as classes existem.

### A espera total não se move. Em nada.

A última coluna daquela tabela é o número que uma central de atendimento reporta, e ele oscila por um fator
de **1,5663** entre as duas ordens de prioridade. Agora pondere cada demanda pelo tempo de atendimento que
ela traz, em vez de contá-la uma vez:

| Ordem | espera média reportada | espera média por dia de trabalho |
| --- | --- | --- |
| primeiro a chegar | 2,5612 d | **2,5540477739** d |
| `priority` | 3,0358 d | **2,5540477739** d |
| `reversed` | 1,9382 d | **2,5540477739** d |

Isso não é coincidência nem aproximação de regime estacionário. A área sob a curva de trabalho não
concluído ao longo de um período ocupado é a mesma sob toda disciplina que nunca fica ociosa havendo
trabalho à espera, e cada demanda contribui `atendimento × espera + atendimento² / 2` para ela. O segundo
termo não depende da ordem, então `sum(atendimento × espera)` **não pode** depender da ordem — não
aproximadamente, não em expectativa, mas em cada realização. É asseverado a 1e-12 relativo e vale até a
décima segunda casa decimal em toda utilização varrida.

> **Priorização não é melhoria. É alocação.** O estoque de espera é fixado por quanto trabalho chega e
> quão rápido o time é. Uma ordem de prioridade decide quem o carrega, e nada além disso.

E a métrica que diria isso a um gestor não é a que está no painel. A espera média reportada sobe **18,5%**
sob a ordem que protege as demandas críticas e cai **24,3%** sob a ordem que as abandona, porque `melhoria`
é ao mesmo tempo a classe mais numerosa e a mais barata de servir. **O KPI da central premia a disciplina
que faz demandas críticas esperarem 6,7375 dias.**

### O que priorizar compra de fato, e o teto que não pode passar

| Ordem | `critico` cumpre a meta de 2 dias | `melhoria` cumpre a meta de 6 dias |
| --- | --- | --- |
| primeiro a chegar | 0,3752 | 0,8486 |
| `priority` | **0,6295** | 0,7264 |
| `reversed` | 0,3207 | 0,9925 |

Priorizar vale 25 pontos reais de cumprimento no crítico, e eles são comprados de `melhoria`. Mas
**0,7956** é a fração de demandas críticas que cumpriria uma meta de dois dias *sem fila nenhuma* — o
atendimento por si só passa de dois dias uma vez em cada cinco. Ou seja: um quinto daquela meta nunca foi
alcançável por sequenciamento, em nenhuma utilização, sob nenhuma ordem. Ordenar a fila fechou 60% da lacuna
que ordenar poderia fechar, e o resto é uma meta escrita contra um processo cuja própria variação a proíbe.

### Um por cento mais de demanda

A espera é convexa na utilização, e a elasticidade é exatamente `1 / (1 − u)`:

| Utilização | espera média por dia de trabalho | % de espera por % de demanda |
| --- | --- | --- |
| 0,40 | 0,4925 d | 1,667 |
| 0,50 | 0,7408 d | 2,000 |
| 0,78 | 2,5957 d | **4,545** |
| 0,90 | 6,8417 d | 10,000 |
| 0,98 | 24,2435 d | 50,000 |

Na 0,78 declarada, um por cento mais de demanda compra quatro e meio por cento mais de espera; em 0,90
compra dez. Pela invariância acima, **nenhuma disciplina muda uma única linha daquela tabela.** As únicas
alavancas sobre a espera total são o volume de trabalho que chega e a capacidade que o atende, e uma revisão
de priorização que não produz nenhum dos dois decidiu quem espera sem mudar quanta espera existe.

### E o único erro deste repositório que tem sinal

As ondas 1, 2 e 4 acharam, cada uma, um erro que muda de sinal com um parâmetro que ninguém reporta, de modo
que nenhuma correção mental existe. Este é diferente, e pior. As formas fechadas acima são limites de regime
estacionário, e o que torna a espera grande perto da capacidade é um número pequeno de períodos ocupados
muito longos — então, à medida que o servidor enche, o número de observações *independentes* numa corrida
colapsa mesmo que o número de demandas não colapse. Em 0,98, um período ocupado contém **0,2121** deste
fluxo inteiro de 60.000 demandas: 12.724 demandas numa única pilha ininterrupta.

| Utilização | 5.000 demandas | 20.000 demandas | 60.000 demandas |
| --- | --- | --- | --- |
| 0,78 | 0,7048 | 0,9847 | 0,9873 |
| 0,95 | 0,4289 | 0,9367 | 0,9641 |
| 0,98 | 0,2442 | 0,6238 | **0,8422** |

Nove leituras de nove estão **abaixo** da verdade, e perto da capacidade mesmo 60.000 demandas leem 16%
menos. Uma observação curta de uma fila não se dispersa em torno da resposta; ela subestima, porque os
acúmulos longos que carregam a média são justamente os que uma janela curta tem menos chance de conter. **A
grandeza que uma revisão de capacidade mais quer — quão ruim fica quando estamos quase cheios — é a que uma
observação finita é menos capaz de reportar, e o erro está na direção que dá sensação de segurança.**

O que não é hipotético, porque uma revisão trimestral é uma observação muito curta. Corte este fluxo
imutável em fatias consecutivas de 180 dias — mesma taxa de chegada, mesmos tempos de atendimento, mesma
disciplina, mesma utilização, nada diferente entre elas — e leia cada uma como uma revisão leria:

| | |
| --- | --- |
| Fatias de 180 dias | 277, com média de 216,6 demandas cada |
| Espera média verdadeira | 2,5318 d |
| A fatia mais baixa lê | **0,6441 d** — atribuível a uma mesa em 0,50 de utilização |
| A fatia mais alta lê | **9,3057 d** — atribuível a uma mesa em 0,90 de utilização |
| Mais alta sobre mais baixa | **14,4486×** |
| Intervalo que um revisor desenharia (4 × sd/√n) | ± 0,6925 d |
| Intervalo que as fatias de fato mostram | ± 5,8781 d |
| Subestimado por | **8,4879×** |

Nada mudou. A mesma mesa, lida um trimestre por vez, reporta uma espera média em qualquer ponto de um fator
de catorze, e o intervalo de confiança que um revisor desenharia em torno dela é oito vezes estreito demais.

> **Antes de ler uma mudança no tempo de espera de uma fila como mudança na fila, pergunte quantos acúmulos
> independentes a leitura contém.** Não quantos tíquetes — quantas vezes a fila esvaziou. Em 0,78 isso é um
> quinto da contagem de tíquetes; em 0,98 é um cinquenta avos.

O intervalo é estreito demais por uma razão que importa além daquela tabela, e é por isso que todo erro
padrão desta onda é agrupado. Esperas numa fila não são observações independentes: uma demanda que espera
muito chegou atrás de uma pilha, e a seguinte também. O que *é* independente é o período ocupado — cada um
começa com o sistema vazio e não carrega memória do anterior. Tratar 60.000 esperas como 60.000 sorteios
independentes subestima o intervalo por entre **1,482** e **6,362** vezes, dependendo da classe e da ordem,
pior para a classe cuja espera é mais causada por outras demandas. O custo é honesto: estas conferências de
forma fechada detectam um erro de **7,01%** a **20,23%** e não menor, onde o intervalo ingênuo teria
reivindicado tão pouco quanto **2,57%** e estaria errado.

Esse período ocupado é o mesmo objeto três vezes. Ele torna a invariância exata, torna o intervalo honesto,
e é o que permitiu simular as duas ordens de prioridade: uma recursão de 60.000 passos vira milhares de
recursões independentes que rodam ao mesmo tempo, precisamente *porque* nenhuma ordenação da fila pode mover
os instantes em que o servidor fica ocioso.

## E a classe que ninguém conhece: a mesa de triagem

A fila da onda 5 serve a classe. Nenhuma mesa de entrada consegue fazer isso, porque a classe não está
escrita na demanda — alguém decide, no balcão, com informação parcial, antes de se saber o que torna a
demanda urgente. Daqui em diante há duas classes por demanda: **a que determina quanto o atraso dela custa e
a que está escrita no tíquete.** A fila serve a segunda.

[`sql/a0_triage.sql`](sql/a0_triage.sql) acrescenta uma matriz de confusão declarada entre as duas — uma
demanda crítica é reconhecida em 75% dos casos, uma `melhoria` é escalada para `critico` em 8% — e roda a
mesma fila sobre os rótulos. As demandas, os tempos de atendimento e a utilização são idênticos aos da onda
5. Só muda a fila em que cada demanda entra.

### O rótulo não é a classe

| Rótulo | demandas que o carregam | fração de todas as demandas | fração que pertence ali |
| --- | --- | --- | --- |
| `critico` | 10084 | **0,1681** | **0,4509** |
| `padrao` | 22600 | 0,3767 | 0,5905 |
| `melhoria` | 27316 | 0,4553 | 0,9215 |

A classe crítica é 10% das demandas. O *rótulo* crítico é 16,81% delas, e **menos da metade dos tíquetes que
o carregam pertence ali.** Dos 10084 tíquetes rotulados `critico`, **4547** vieram da classe crítica e
**5537** vieram das outras duas — porque o rótulo recolhe uma fração pequena de duas classes que são três e
seis vezes maiores que aquela que lhe dá nome, e uma fração pequena de algo grande é maior que uma fração
grande de algo pequeno. Nenhuma falha de disciplina é necessária.

### Quanto custa, e a quem é pago

| Classe | espera se a triagem fosse perfeita | espera com esta mesa | razão | sem prioridade nenhuma |
| --- | --- | --- | --- | --- |
| `critico` | 0,6961 d | **1,0383 d** | **1,4916** | 2,5461 d |
| `padrao` | 1,1636 d | 1,6401 d | 1,4095 | 2,5624 d |
| `melhoria` | 4,3583 d | **3,8716 d** | **0,8883** | 2,5632 d |

As demandas genuinamente críticas esperam **49,2% mais** do que esperariam sob uma mesa que nunca erra, e o
cumprimento da meta de dois dias cai de 0,6295 para 0,5941. A classe `melhoria` fica **melhor**.

Isso não é coincidência e é a razão de existir desta onda. Reetiquetar a fila não pode mudar quanto trabalho
há nela, então a invariância da onda 5 tem de sobreviver a uma mesa que erra um terço das suas chamadas — e
sobrevive, exatamente:

| | espera ponderada por trabalho | contra triagem perfeita |
| --- | --- | --- |
| Prioridade crítica perfeita | 99015,6062 | — |
| Esta mesa de triagem | 99015,6062 | **1,000000000000** |

> **Um erro de triagem não é desperdício. É uma transferência.** Cada dia extra que a classe crítica espera é
> um dia que outra classe não espera, e a outra classe é quem o rótulo errado mandou para a frente.

As duas metades da aritmética são conferidas separadamente. A fórmula de Cobham se aplica aos *rótulos*,
cujas distribuições de atendimento agora são misturas: 0,6957, 1,3640 e 5,0720 dias, contra 0,7042, 1,3984 e
4,9970 simulados, com pior desvio de 0,867 erro padrão agrupado. A espera de uma classe verdadeira é então
uma média condicional sobre os rótulos em que seus membros caem, o que prevê 1,0482 dias para `critico`
contra 1,0383 simulado — 0,257 erro padrão. É a única cifra deste repositório que é composição de duas
derivações, e por isso a única conferida nos dois níveis.

### E o painel melhora

A espera média reportada por demanda sob prioridade crítica perfeita é 3,0358 dias. Sob esta mesa de triagem
é **2,9201** — a métrica que uma central publica fica **melhor** à medida que a mesa de triagem fica pior,
porque a sobre-escalação leva as demandas numerosas e baratas para a frente e só os poucos críticos pagam.

É pior que isso. Tome as seis ordens em que três classes podem ser servidas, derive cada uma, e ordene pelo
que de fato custam à urgência declarada:

| Ordem | custo à urgência declarada | contra a melhor | espera média reportada |
| --- | --- | --- | --- |
| `p1 p2 p3` | **5,2657** | 1,0000 | 3,0691 d |
| `p2 p1 p3` | 5,6603 | 1,0749 | 3,0240 d |
| `p1 p3 p2` | 7,5822 | 1,4399 | 2,4900 d |
| `p3 p1 p2` | 8,6627 | 1,6451 | 2,3160 d |
| `p2 p3 p1` | 10,8461 | 2,0598 | 2,1891 d |
| `p3 p2 p1` | **11,7533** | 2,2321 | **1,9622 d** |

O total ponderado por trabalho é 2,0174602407 em toda linha, como tem de ser. A espera média reportada cai
monotonicamente tabela abaixo. **A métrica ordena as seis ordens de prioridade possíveis exatamente ao
inverso do custo verdadeiro delas — todas as seis, não aproximadamente.** Uma operação que otimiza seu tempo
médio de tratamento publicado está escolhendo a pior ordem disponível, e os números vão mostrá-la melhorando
o caminho inteiro.

### As duas formas de errar não valem o mesmo

Varridas uma por vez, em forma fechada, contra a espera da classe crítica sob triagem perfeita:

| Taxa de erro | sobre-escalação | sub-reconhecimento |
| --- | --- | --- |
| 5% | 1,0385 | **1,2675** |
| 10% | 1,0800 | **1,5278** |
| 20% | 1,1739 | 2,0280 |
| 50% | 1,5883 | 3,3826 |
| 100% | 3,8580 | **5,2470** |

A um décimo, não reconhecer uma demanda crítica custa **52,8%** à classe crítica e escalar uma rotineira lhe
custa **8,0%** — um fator de **6,6**. O total ponderado por trabalho não se move em nenhum dos dezesseis
pontos. E os dois limites não são simétricos de um jeito que importa:

- Escale **tudo** e a classe crítica espera 3,8580 vezes seu ideal, que é exatamente a espera do primeiro a
  chegar. Sobre-escalação total não é pior que nunca ter ordenado a fila.
- Erre **tudo** e ela espera 5,2470 vezes seu ideal, que é *pior* que nunca ter ordenado.

Então existe uma taxa em que um sistema de prioridade deixa de valer a pena, e ela é computável: passando de
**0,62** de sub-reconhecimento, as demandas genuinamente críticas estariam melhor numa fila não ordenada.
Ordenar uma fila por um rótulo errado com frequência suficiente não é uma versão fraca de ordenar. É
desorientação ativa.

### A ordem certa não é a urgente

A onda 5 provou que nenhuma ordem muda o total, então a única coisa que uma ordem faz é decidir quem espera —
e decidir exige dizer quanto a espera custa. [`sql/00_parameters.sql`](sql/00_parameters.sql) declara isso
como taxa de câmbio e não como dinheiro: um dia de atraso em `critico` vale 10 dias em `melhoria`, `padrao`
vale 3. Dados os custos, a ordem que minimiza a espera ponderada é conhecida, e **não** é "mais urgente
primeiro":

> Ordene por **urgência dividida pelo tempo médio de atendimento**, não por urgência.

| Classe | urgência | atendimento médio | urgência por dia de atendimento | margem antes de a ordem inverter |
| --- | --- | --- | --- | --- |
| `critico` | 10 | 1,2381 d | **8,0768** | **1,9797** |
| `padrao` | 3 | 0,7353 d | 4,0797 | **2,0497** |
| `melhoria` | 1 | 0,5024 d | 1,9904 | — |

A regra reproduz `p1 p2 p3`, a vencedora das seis — então nesta conta a intuição está certa. A coluna que
vale ler é a última. A margem que protege a resposta intuitiva é um fator de **dois**, não de dez, e é a
razão entre dois números que nenhuma política de escalação contém. Varrer o tempo de atendimento da classe
crítica a carga crítica constante — o mesmo trabalho chegando como muitos incidentes rápidos ou como poucos
lentos — localiza o ponto de ruptura exatamente:

| Atendimento crítico | o que crítico-primeiro custa contra padrão-primeiro |
| --- | --- |
| 0,5000 d | 0,8046 |
| 1,2381 d *(declarado)* | 0,9303 |
| 2,4000 d | 0,9982 |
| **2,4512 d** | **o limiar** |
| 2,5000 d | 1,0016 |
| 6,0000 d | 1,0544 |

Em 2,4512 dias de atendimento, crítico-primeiro deixa de ser a melhor ordem. O limiar é exatamente
`urgência(critico) × atendimento(padrao) ÷ urgência(padrao)`, e não contém taxa de chegada nem utilização.
**Uma classe bloqueia a fila em proporção ao tempo que leva para ser liberada, e a urgência não escala com
isso.** A sala de crise de incidente maior que ocupa o time inteiro por três dias enquanto duzentas
solicitações padrão acumulam atrás não é falha de execução. É o que a política declarada pede, passando de
um limiar que a política nunca enuncia.

### Qual das duas alavancas puxar

Os dois achados estão na mesma escala, e não valem o mesmo esforço:

| | custo à urgência declarada |
| --- | --- |
| Triagem perfeita, melhor ordem | 5,2657 |
| Triagem perfeita, segunda melhor ordem | 1,0749× |
| **Esta mesa de triagem, melhor ordem** | **1,1157×** |
| Triagem perfeita, pior ordem | 2,2321× |

Um erro realista na *ordem* custa 7,5%. A mesa de triagem declarada custa **11,6%** — e a classe crítica não
sente 11,6% disso. Ela sente **1,5632** vezes sua espera ideal, um excesso de **56,3%**, cerca de cinco vezes
o excesso que a conta inteira carrega. Uma revisão de priorização gasta seu tempo discutindo a ordem. A ordem
é o problema mais barato.

## E o que custa saber: a mesa de triagem gasta a capacidade que ela protege

A onda 6 deu à mesa uma taxa de erro e não cobrou nada por ela. Essa é a última ficção que restava.
Classificar exige olhar, e quem olha é quem trabalha — então **a acurácia é comprada com a única coisa que
a ordem de prioridade tinha para alocar.**

[`sql/b0_effort.sql`](sql/b0_effort.sql) torna isso explícito. Cada olhada custa ao servidor **0,02 dia**
(cerca de meia hora) e aponta a classe verdadeira com probabilidade **0,70**, escolhendo uniformemente uma
das outras duas quando erra. O rótulo é a moda de `looks` olhadas independentes. Nada na matriz de confusão
é declarado agora: ela sai de um multinomial exato sobre as formas de os votos caírem, de modo que a
acurácia é *derivada* do esforço. Mesmo assim é conferida contra um sorteio do gerador declarado — nove
células, pior desvio de **2,093** erros padrão.

### A acurácia não é monótona no esforço

| Olhadas | `critico` | `padrao` | `melhoria` |
| --- | --- | --- | --- |
| 1 | 0,7000 | 0,7000 | 0,7000 |
| **2** | **0,9100** | 0,7000 | **0,4900** |
| 3 | 0,8785 | 0,7840 | 0,7840 |
| **4** | 0,9163 | 0,8501 | **0,7840** |
| 8 | 0,9712 | 0,9481 | 0,9250 |

Um número par de olhadas pode empatar, e um empate tem de ser desempatado por regra. A regra declarada
manda o empate para a classe mais urgente — que é o que uma mesa sob pressão faz — e a consequência é
exata: **duas olhadas deixam `melhoria` pior que uma olhada**, 0,4900 contra 0,7000. A segunda olhada não
acrescenta informação àquela classe, acrescenta uma moeda que o desempate resolve contra ela.

E a quarta olhada compra **nada** para a classe de baixo — 0,7840 com três olhadas, 0,7840 com quatro. Uma
olhada inteira de capacidade, gasta, por exatamente zero. **Esforço ímpar ajuda toda classe; esforço par só
ajuda a classe que o desempate favorece.**

Esse desempate é uma transferência pura, e o espelho é exato. Sob a regra tolerante, com duas olhadas, os
números são 0,4900 / 0,7000 / 0,9100 — as mesmas três cifras, invertidas. A regra não cria acurácia. Ela a
move. Com duas olhadas, a escolha entre as duas regras vale **7,6569 contra 8,5145** na escala de urgência
declarada, uma oscilação de **11,2%** vinda de uma linha que não aparece em nenhuma política de triagem.

### O ótimo é uma olhada, e três é pior que nenhuma

| Olhadas | utilização | espera `critico` | espera `melhoria` | custo | contra não triar |
| --- | --- | --- | --- | --- | --- |
| 0 *(sem triagem)* | 0,7799 | 2,5868 d | 2,5868 d | 7,8212 | 1,0000 |
| **1** | 0,8040 | 1,5789 d | 4,3030 d | **7,1449** | **0,9135** |
| 2 | 0,8282 | 1,1868 d | 5,3872 d | 7,6569 | 0,9790 |
| 3 *(declarado)* | 0,8523 | 1,3364 d | 6,8672 d | 8,7071 | **1,1133** |
| 5 | 0,9006 | 1,2124 d | 11,7301 d | 12,1307 | 1,5510 |
| 8 | 0,9730 | 1,5938 d | 51,0349 d | 41,6458 | **5,3248** |

Uma olhada paga 8,7%. Duas olhadas pagam 2,1%. **Três olhadas — o cenário declarado — custam 11,3% mais que
não triar**, e oito olhadas custam **5,3 vezes** mais. O esforço declarado está deliberadamente passando do
ótimo: um parâmetro calibrado na resposta teria escondido a resposta.

Meia hora por demanda, oito vezes, é 0,16 dia de triagem. Isso sozinho leva a utilização de 0,7799 para
0,9730 e multiplica a espera da mesma fila sem ordem de prioridade nenhuma de 2,5868 para **26,3007 dias**
— um fator de **dez**, comprado só com olhar.

**E passando de certo esforço a própria classe crítica fica pior.** `critico` espera 1,5789 dia com uma
olhada, chega ao mínimo de 1,2124 com cinco, e volta a **1,5938 com oito** — pior que com uma olhada. A
classe que a triagem existe para proteger é prejudicada pela triagem, porque a triagem está na fila dela.

### Com que cuidado classificar não é propriedade da mesa

É propriedade de quão cheia a mesa já está. Varrendo a utilização *antes* da triagem:

| Utilização antes da triagem | olhadas que valem | olhadas possíveis | contra não triar |
| --- | --- | --- | --- |
| 0,40 | 1 | 8 | 0,9629 |
| 0,60 | 1 | 8 | 0,9268 |
| **0,75** | 1 | 8 | **0,9112** |
| 0,85 | 1 | 5 | 0,9451 |
| 0,88 | 1 | 4 | 0,9874 |
| **0,89** | **0** | 3 | **1,0000** |
| 0,95 | **0** | **1** | 1,0000 |

Três coisas nessa tabela.

**A triagem deixa de pagar em 0,89.** Passando disso, o esforço que compraria um rótulo melhor custa mais
espera do que o rótulo melhor economiza, e a política correta é não ordenar nada e não olhar nada.

**O ganho tem pico no meio, em 0,75 e 8,9%.** Abaixo dele há pouca espera para realocar, então um rótulo melhor
vale menos; acima dele o olhar é ruinoso. A triagem se paga numa faixa, de mais ou menos 0,60 a 0,85, e vale
mais onde a mesa está ocupada mas não afogada.

**E o teto colapsa antes do ótimo.** Em 0,78 a mesa conseguiria fazer oito olhadas; em 0,85 só cinco; em
0,95 **exatamente uma**, porque a segunda empurraria a utilização acima de um e a fila não teria regime
estacionário nenhum.

> **Quanto mais ocupada a mesa, menos ela pode se permitir saber.** Que é exatamente o contrário do que
> acontece: quando uma fila explode, a primeira reação é uma reunião de triagem.

### As três ondas juntas

A onda 5 provou que nenhuma ordem de prioridade reduz a espera total — só decide quem a carrega. A onda 6
mostrou que o rótulo pelo qual a ordem ordena não é a classe, e que errá-lo é transferência, não perda. A
onda 7 põe preço em acertá-lo, e descobre que o preço é cobrado na mesma moeda que a ordem estava alocando.

Então o arco fecha numa prescrição só, e ela não é de sequenciamento:

> **Em utilização alta existe uma alavanca, e ela é capacidade.** Ordenar não ajuda, classificar piora, e
> classificar para de funcionar antes de ordenar.

A única simplificação que merece ser nomeada: o tempo de classificação está embutido no tempo de
atendimento da demanda, em vez de cobrado como etapa própria na entrada. Essa é a escolha conservadora, e
deliberadamente: a triagem real é paga *antes* de a ordenação acontecer, então ela bloqueia a fila mais cedo
do que este modelo bloqueia e custa mais, não menos.

## E a sofisticação que perde para uma olhada

A onda 7 gasta o mesmo esforço em toda demanda, o que nenhuma mesa faz. Uma mesa real para cedo nas óbvias
e continua olhando as ambíguas. [`sql/c0_stopping.sql`](sql/c0_stopping.sql) constrói isso: depois de cada
olhada a posteriori sobre as três classes é recalculada por Bayes, e a mesa se compromete assim que a maior
posteriori cruza um limiar declarado. O limiar parametriza toda a faixa num número só — a maior fração do
prior é 0,60, então **"não triar" não é política separada aqui, é a ponta baixa desta.**

Esta onda foi construída para mostrar que a regra sequencial ganha. Ela não ganha, e a razão vale mais do
que o resultado valeria.

### O esforço de fato vai onde é necessário

| Limiar | `critico` | `padrao` | `melhoria` |
| --- | --- | --- | --- |
| 0,70 | 2,3810 olhadas | 2,4352 | 1,5747 |
| 0,80 | **3,6572 olhadas** | 2,6283 | **1,8143** |
| 0,90 | 4,8597 olhadas | 3,5532 | 3,2911 |

No 0,80 declarado a mesa gasta **2,0158 vezes** mais olhadas confirmando uma demanda crítica do que uma
melhoria, e não é desleixo — é correção. O prior é 0,10 contra `critico`, então comprometer-se com ele exige
mais evidência. Essa parte do projeto funciona exatamente como pretendido.

Mas veja o que custa. `critico` já é a classe mais lenta de atender, com 1,2381 dia. Agora é também a mais
lenta de classificar. **A classe que mais bloqueia a fila é a mais cara de reconhecer**, e as duas coisas se
compõem.

### E os rótulos saem piores onde importa

| Regra no próprio ótimo (θ = 0,65) | rótulos certos | `critico` certo | custo |
| --- | --- | --- | --- |
| Maximizar acurácia | **0,7872** | **0,5590** | 7,6623 |
| Minimizar custo esperado | 0,7307 | 0,6789 | **7,4580** |
| *Uma olhada fixa (onda 7)* | *0,7000* | *0,7000* | ***7,1449*** |

Três coisas, e a terceira é a onda.

**A regra que maximiza acurácia reconhece a classe crítica 0,5590 das vezes** — pior que os 0,7000 que uma
única olhada crua consegue simplesmente reportando o que viu. Bayes encolhe na direção da taxa-base; a
taxa-base diz "provavelmente não é crítico"; e a onda 6 estabeleceu que deixar de reconhecer uma demanda
crítica custa 6,6 vezes o que escalar uma rotineira custa. **Cada unidade de correção estatística é paga na
moeda que a operação valoriza.**

**Tornar a regra sensível a custo confirma o diagnóstico.** Comprometer-se com a classe de maior posteriori
*vezes a urgência declarada* em vez da maior posteriori faz o custo cair de 7,6623 para 7,4580 — melhor em
todo limiar acima do degenerado — acertando **menos rótulos**, 0,7307 contra 0,7872. *Menos rótulos certos,
menos espera.* As duas metades disso estão asseveradas.

**E as duas ainda perdem para uma olhada fixa.** Não por muito — 4,4% para a regra de custo — mas perdem.

### Em toda utilização, inclusive nas com folga

| Utilização antes da triagem | melhor limiar | olhadas fixas | sequencial ÷ fixo |
| --- | --- | --- | --- |
| 0,40 | 0,65 | 1 | 1,0144 |
| 0,60 | 0,65 | 1 | 1,0216 |
| 0,78 | 0,65 | 1 | 1,0439 |
| 0,82 | 0,65 | 1 | **1,0569** |
| 0,88 | 0,60 | 1 | 1,0128 |
| 0,89 e acima | 0,60 | 0 | 1,0000 |

Eu esperava que a regra sequencial ganhasse onde há folga, pelo raciocínio de que capacidade barata torna
acurácia acessível. Ela nunca ganha. Em 0,40 de utilização — onde olhar custa quase nada — uma olhada crua
ainda bate a melhor regra de parada por 1,4%, porque a desvantagem da regra não é o custo dela. É o objetivo
dela. Usar o prior é o que a faz perder, e o prior não fica mais barato quando o servidor esvazia.

> **Uma única olhada crua, escalando pelo que ela reportar, bate todo refinamento bayesiano dela — porque o
> refinamento encolhe na direção de uma taxa-base que é contra a única classe que não se pode perder.**

É por isso que bons protocolos de triagem são escritos como critérios de exclusão e não como estimativas de
probabilidade. "Se houver qualquer indicador de gravidade, escale" é a regra da olhada crua. "Estime a
probabilidade e atue no caso mais provável" é a regra que esta onda mostra perdendo. A primeira é pior em
rotular e melhor em não perder, e só a segunda dessas está no placar.

### Um custo real e negligenciável

Como o esforço agora é resultado e não parâmetro, ele tem variância — e o trabalho residual de Pollaczek e
Khinchine cobra o *segundo* momento do tempo de serviço, do qual o tempo de triagem faz parte. Então uma
regra que olha um número variável de vezes custa mais que uma que olha E[K] vezes exatas. O mecanismo é
real; o tamanho, aqui, não é: **1,0015 no pior caso**, um quinto de um por cento, porque uma olhada custa
0,02 dia contra um atendimento de 0,6461. Importaria se olhar fosse caro em relação a fazer, e vale nomear
para que o leitor saiba quando se preocupar.

### Ondas 5 a 8

| | |
| --- | --- |
| Onda 5 | Nenhuma ordem de prioridade reduz a espera total. Só decide quem a carrega. |
| Onda 6 | O rótulo pelo qual a ordem ordena não é a classe, e errá-lo é transferência, não perda. |
| Onda 7 | Acertá-lo custa a capacidade que faz o rótulo importar. Acima de 0,89 de utilização, não trie. |
| Onda 8 | E a forma sofisticada de acertá-lo é pior que a forma crua, em toda utilização. |

> **Olhe uma vez. Escale a qualquer indicação. Gaste a discussão em capacidade.**

## O que fazer em vez disso

- **Leia coortes, e diga a idade.** "38% dos leads que entraram em março fecharam em até 60 dias" é uma
  frase que sobrevive a um pipeline crescendo. "A conversão foi de 38% em maio" não.
- **Publique o atraso ao lado da taxa.** A diferença entre a taxa eventual e a taxa de coorte *é* o
  atraso; um relatório de funil sem eixo de tempo escolheu silenciosamente a taxa eventual e a chamou de
  mensal.
- **Confira o teto.** Uma etapa lendo acima do produto das suas próprias taxas históricas é o sinal
  vermelho mais barato que existe, e custa uma consulta.
- **Pergunte o que as entradas fizeram.** Antes de ler qualquer movimento numa taxa de funil como
  comportamento, olhe se o topo do funil cresceu. Nesta conta essa única pergunta explica um fator de
  dois.
- **Pondere a espera pelo trabalho que ela carrega, não pela contagem de tíquetes.** A média ponderada por
  tíquete pode ser melhorada servindo os itens baratos primeiro, e fazer isso faz os críticos esperarem
  mais. A média ponderada por trabalho não pode ser melhorada por ordenação nenhuma, e é exatamente por
  isso que é a que vale reportar: ela só se move quando algo real se move.
- **Leve uma proposta de priorização e um número de capacidade à mesma reunião.** Priorização decide quem
  espera. Só o trabalho que chega e a capacidade que o atende decidem quanta espera existe, e em 0,78 de
  utilização um por cento mais de demanda custa quatro e meio por cento mais de espera.
- **Conte quantas vezes a fila esvaziou, não quantos itens ela tratou.** Esse é o tamanho de amostra de
  qualquer afirmação sobre espera. Um trimestre desta mesa contém 216,6 demandas e cerca de quarenta e oito
  acúmulos, e é por isso que um trimestre dela pode ler em qualquer ponto de um fator de catorze sem que
  nada tenha mudado.
- **Confira uma meta de serviço contra o tempo de atendimento sozinho antes de culpar a fila.** Um quinto
  das demandas críticas aqui perde uma meta de dois dias pelo tempo de atendimento em si. Sequenciamento
  nenhum recupera isso, e uma revisão que gasta seu tempo em ordenação vai continuar perdendo por aquele
  quinto.
- **Audite o que está no rótulo do topo antes de discutir a ordem.** Menos da metade dos tíquetes rotulados
  como críticos aqui pertence ali, e isso sozinho custa 49,2% da espera à classe genuinamente crítica. A
  ordem é o problema mais barato: um erro realista nela custa 7,5% contra 11,6% da triagem.
- **Gaste esforço de triagem em reconhecer o urgente, não em reprimir o inflado.** Deixar de identificar uma
  demanda crítica lhe custa 6,6 vezes o que escalar uma rotineira lhe custa, à mesma taxa de erro. Passando
  de 0,62 de sub-reconhecimento, o sistema de prioridade é pior para a classe crítica que nenhum sistema.
- **Divida urgência por tempo de atendimento antes de ordenar.** A ordem que minimiza o custo da espera é
  urgência por dia de atendimento, não urgência. Nesta conta as duas coincidem — por um fator de dois, que é
  a razão entre dois números que nenhuma política de escalação escreve.
- **Nunca deixe um tempo médio de tratamento julgar uma política de prioridade.** Nas seis ordens em que três
  classes podem ser servidas, a espera média reportada as ordena exatamente ao inverso do custo verdadeiro.
- **Precifique a triagem antes de comprá-la.** O tempo de classificação é servido pelo mesmo servidor que o
  trabalho, então eleva a utilização que a ordem de prioridade existe para administrar. Uma olhada por
  demanda paga 8,7% aqui; três custam 11,3% *mais* que não triar.
- **Confira a utilização antes de pedir um rótulo melhor.** O esforço que vale gastar cai à medida que a
  mesa enche e chega a zero em 0,89, e o número de olhadas sequer viáveis colapsa antes — em 0,95 uma
  segunda olhada empurraria a utilização acima de um. Quando uma fila explode, reunião de triagem é o
  reflexo errado: nesse ponto a única alavanca é capacidade.
- **Escreva a regra de desempate.** Um número par de verificações produz empates, e a regra que os resolve
  transfere acurácia entre classes sem criar nenhuma. Aqui ela oscila o custo total em 11,2%, e não aparece
  em documento de política nenhum.
- **Prefira um número ímpar de verificações a um par.** Ir de três para quatro custa uma olhada inteira de
  capacidade e compra nada para a classe de baixo — 0,7840 nos dois casos.
- **Escreva o protocolo como critério de exclusão, não como estimativa.** "Escale se houver qualquer
  indicador de gravidade" bate "estime a probabilidade e atue no caso mais provável" aqui em toda utilização
  de 0,40 a 0,95. Uma estimativa de probabilidade encolhe na direção da taxa-base, e a taxa-base é contra a
  classe cuja classificação errada custa mais.
- **Se tiver de pesar evidência, pese por custo e não por verossimilhança.** Comprometer-se com a classe de
  maior posteriori vezes a urgência bate comprometer-se com a maior posteriori em todo limiar — acertando
  *menos* rótulos.

## Rodando

```bash
make duckdb   # baixa o CLI do DuckDB para .bin, uma vez
make build    # roda cada modelo em sql/, em ordem
make check    # build, depois cada asserção em tests/
make report   # build, depois imprime as tabelas publicadas
```

`make check` é o que libera um push, e é o que o CI roda. Não há Python, não há notebook e não há serviço
para subir: o repositório inteiro é arquivo SQL e um Makefile.

| Caminho | O que contém |
| --- | --- |
| [`sql/00_parameters.sql`](sql/00_parameters.sql) | Todo número declarado, os seis funis, e o gerador escrito em aritmética. |
| [`sql/10_subjects.sql`](sql/10_subjects.sql) | Entradas por funil por dia, compostas no crescimento declarado. |
| [`sql/20_events.sql`](sql/20_events.sql) | O log de eventos: uma linha por sujeito e por etapa efetivamente alcançada. |
| [`sql/30_readings.sql`](sql/30_readings.sql) | O mesmo funil lido de quatro maneiras, e a distorção entre duas delas. |
| [`sql/40_closed_form.sql`](sql/40_closed_form.sql) | As duas leituras de taxa derivadas no papel, e os dois mecanismos isolados. |
| [`sql/50_velocity.sql`](sql/50_velocity.sql) | As quatro leituras de novo na dimensão do tempo, suas formas fechadas, e o ranking de velocidade. |
| [`sql/60_survival.sql`](sql/60_survival.sql) | O estimador produto-limite, suas três formas fechadas, a precisão que ele compra e a mediana que geralmente não existe. |
| [`sql/70_frailty.sql`](sql/70_frailty.sql) | Duas classes declaradas de sujeito com atraso médio inalterado, e a forma fechada da mistura. |
| [`sql/80_archiving.sql`](sql/80_archiving.sql) | A revisão de pipeline que censura por julgamento, o que ela custa à estimativa, e a janela em que não pode. |
| [`sql/90_queue.sql`](sql/90_queue.sql) | Um servidor, três classes de prioridade, três disciplinas: a espera que cada uma produz, o total que não se move, a varredura de utilização e o que uma fatia de 180 dias consegue dizer. |
| [`sql/95_queue_closed_form.sql`](sql/95_queue_closed_form.sql) | A fila derivada no papel — Pollaczek–Khinchine, Cobham, e a lei de conservação de que a invariância é um caso. |
| [`sql/a0_triage.sql`](sql/a0_triage.sql) | O rótulo que a fila de fato serve: uma matriz de confusão declarada, a fila refeita sobre ela, o que cada classe perde e a quem isso é pago. |
| [`sql/a5_urgency.sql`](sql/a5_urgency.sql) | Cobham sobre os rótulos composto nas classes, as duas direções de erro varridas, as seis ordens enumeradas, e a regra que nomeia a vencedora. |
| [`sql/b0_effort.sql`](sql/b0_effort.sql) | Acurácia derivada do esforço por um multinomial exato, conferida contra um sorteio; o que o olhar custa ao servidor; e o ótimo interior. |
| [`sql/b5_effort_sweep.sql`](sql/b5_effort_sweep.sql) | O esforço que vale gastar contra a utilização já carregada, e o ponto a partir do qual a triagem deixa de pagar. |
| [`sql/c0_stopping.sql`](sql/c0_stopping.sql) | Uma mesa sequencial: a caminhada da posteriori, os dois objetivos de rotulagem sobre a mesma caminhada, e o que a variância do esforço custa. |
| [`sql/c5_stopping_sweep.sql`](sql/c5_stopping_sweep.sql) | A melhor regra de parada contra uma olhada fixa, em toda utilização — a comparação que saiu ao contrário. |
| [`tests/`](tests) | Dezessete arquivos de asserção. Cada um devolve as linhas que quebram uma afirmação; zero linhas é aprovação, e o harness confere também o código de saída. |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | O que está construído, o que está deliberadamente ausente, o que segue aberto, e os defeitos. |

## Como as afirmações são mantidas honestas

**Verificação contra uma derivação, nunca contra a própria saída do código.** A etapa dois fecha
algebricamente, então a simulação é comparada com aritmética feita em separado. A tolerância é de quatro
erros padrão de uma proporção binomial calculada sobre o denominador real — não um número fixo, porque o
`resgate` tem 202 sujeitos na sua janela e a `demanda` tem 6.455.

**O gerador é escrito em aritmética em vez de delegado a uma biblioteca.** Um `random()` com semente é
uma promessa feita por qualquer versão do motor que estiver instalada. Aqui um uniforme é uma mistura do
próprio índice do sorteio: sem estado, sem semente, e sem dependência da ordem em que as linhas são
avaliadas.

**Dois controles sustentam a forma do achado.** O crescimento das entradas é varrido com o atraso fixo; o
atraso é varrido com as entradas estáveis. Cada um isola um mecanismo, e cada um é afirmado como
propriedade monótona em vez de cifra.

**O intervalo considera o que é de fato independente.** As ondas 1 a 4 usam quatro erros padrão de uma
binomial ou de uma média amostral. A onda 5 não pode: as esperas de uma fila são correlacionadas dentro de
um período ocupado, então `sd/√n` subestima o intervalo em até 6,362 vezes. Todo erro padrão da fila é
agrupado por período ocupado, que são independentes porque cada um começa com o sistema vazio — e o custo em
poder de detecção é publicado em vez de escondido.

**E defeitos são registrados em vez de corrigidos em silêncio.** Quinze até aqui, em
[`docs/ROADMAP.md`](docs/ROADMAP.md). O primeiro gerador passou no teste óbvio — a média ficou em 0,49999
e a amplitude preencheu o intervalo — enquanto dois dos seus streams correlacionavam a **−0,42**. O
segundo foi uma asserção minha simplesmente errada: afirmei uma identidade populacional sobre uma
amostra, e seis etapas falharam por menos de um erro padrão.

## Licença

MIT. Ver [`LICENSE`](LICENSE).
