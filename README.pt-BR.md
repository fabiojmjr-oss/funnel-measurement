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

Tudo aqui é **SQL**. Seis arquivos de modelo, oito de asserção, um Makefile que decide a ordem, e nenhuma
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
| [`tests/`](tests) | Oito arquivos de asserção. Cada um devolve as linhas que quebram uma afirmação; zero linhas é aprovação, e o harness confere também o código de saída. |
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

**E defeitos são registrados em vez de corrigidos em silêncio.** Quatro até aqui, em
[`docs/ROADMAP.md`](docs/ROADMAP.md). O primeiro gerador passou no teste óbvio — a média ficou em 0,49999
e a amplitude preencheu o intervalo — enquanto dois dos seus streams correlacionavam a **−0,42**. O
segundo foi uma asserção minha simplesmente errada: afirmei uma identidade populacional sobre uma
amostra, e seis etapas falharam por menos de um erro padrão.

## Licença

MIT. Ver [`LICENSE`](LICENSE).
