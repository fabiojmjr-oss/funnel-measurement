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

Tudo aqui é **SQL**. Nove arquivos de modelo, onze de asserção, um Makefile que decide a ordem, e nenhuma
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
| [`tests/`](tests) | Onze arquivos de asserção. Cada um devolve as linhas que quebram uma afirmação; zero linhas é aprovação, e o harness confere também o código de saída. |
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

**E defeitos são registrados em vez de corrigidos em silêncio.** Sete até aqui, em
[`docs/ROADMAP.md`](docs/ROADMAP.md). O primeiro gerador passou no teste óbvio — a média ficou em 0,49999
e a amplitude preencheu o intervalo — enquanto dois dos seus streams correlacionavam a **−0,42**. O
segundo foi uma asserção minha simplesmente errada: afirmei uma identidade populacional sobre uma
amostra, e seis etapas falharam por menos de um erro padrão.

## Licença

MIT. Ver [`LICENSE`](LICENSE).
