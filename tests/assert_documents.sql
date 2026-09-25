-- The claims the repository makes about itself, asserted in SQL by reading its own files.
--
-- The figure assertions catch a number that moved. They cannot catch a figure quoted in one language and
-- corrected in the other, a model file nothing links, a stage name the disclaimer never declared as
-- invented, or a placeholder left in the text - and in three sibling repositories defects of exactly
-- that class reached the remote before a file like this existed there. DuckDB can read a file as text
-- and list a directory, so none of it needs a second language either.
WITH docs AS (
    SELECT 'README.md' AS name, content FROM read_text('README.md')
    UNION ALL SELECT 'README.pt-BR.md', content FROM read_text('README.pt-BR.md')
    UNION ALL SELECT 'DISCLAIMER.md', content FROM read_text('DISCLAIMER.md')
    UNION ALL SELECT 'docs/ROADMAP.md', content FROM read_text('docs/ROADMAP.md')
),
english AS (SELECT content FROM docs WHERE name = 'README.md'),
portuguese AS (SELECT content FROM docs WHERE name = 'README.pt-BR.md'),
disclaimer AS (SELECT content FROM docs WHERE name = 'DISCLAIMER.md'),
-- Every headline figure, in the spelling each language uses for it.
recorded AS (
    SELECT count(*) AS defects
    FROM (
        SELECT unnest(regexp_extract_all(
            (SELECT content FROM docs WHERE name = 'docs/ROADMAP.md'), '(?m)^\d+\. \*\*'
        )) AS marker
    )
),
words(n, english, portuguese) AS (
    VALUES (1, 'One so far', 'Um até aqui'), (2, 'Two so far', 'Dois até aqui'),
           (3, 'Three so far', 'Três até aqui'), (4, 'Four so far', 'Quatro até aqui'),
           (5, 'Five so far', 'Cinco até aqui'), (6, 'Six so far', 'Seis até aqui'),
           (7, 'Seven so far', 'Sete até aqui'), (8, 'Eight so far', 'Oito até aqui'),
           (9, 'Nine so far', 'Nove até aqui'), (10, 'Ten so far', 'Dez até aqui'),
           (11, 'Eleven so far', 'Onze até aqui'), (12, 'Twelve so far', 'Doze até aqui'),
           (13, 'Thirteen so far', 'Treze até aqui'), (14, 'Fourteen so far', 'Quatorze até aqui'),
           (15, 'Fifteen so far', 'Quinze até aqui')
),
figures(figure) AS (
    VALUES ('1.9826'), ('1.6988'), ('0.9522'), ('0.9907'), ('0.9218'), ('0.9524'),
           ('0.0743'), ('0.0375'), ('0.0602'), ('0.1080'), ('0.0636'), ('0.2198'), ('0.2308'),
           ('0.3529'), ('0.0541'), ('0.0587'), ('0.0737'), ('1.4161'), ('1.3200'), ('1.2335'),
           ('1.2173'), ('0.4871'), ('0.4181'), ('1.0825'), ('0.9292'), ('0.2845'), ('0.1771'),
           ('1.5754'), ('2.3787'), ('1.1651'), ('2.04'),
           -- Wave 2.
           ('26.82'), ('29.07'), ('22.09'), ('20.08'), ('17.55'), ('5.01'),
           ('0.894'), ('1.002'), ('0.818'), ('0.873'), ('0.924'), ('0.964'),
           ('29.15'), ('29.64'), ('27.01'), ('29.24'), ('26.12'), ('18.13'),
           ('19.714'), ('17.511'), ('12.514'), ('0.9857'), ('0.8756'), ('0.6257'),
           ('5.77'), ('1.61'), ('1.11'),
           -- Wave 3.
           ('29.8'), ('0.4453'), ('0.7833'), ('0.1661'), ('0.5820'), ('0.9582'), ('0.9408'),
           ('0.00580'), ('0.00699'), ('0.8302'), ('0.7698'), ('0.9809'), ('0.9506'), ('0.9756'),
           ('0.8953'), ('1.24'), ('1.688'), ('1.05'), ('2.82'), ('0.4992'), ('0.0723'),
           ('19.911'), ('24.231'), ('13.257'), ('0.139'), ('3.183'), ('0.6817'), ('0.1047'),
           -- Wave 4.
           ('0.357143'), ('1.38'), ('17.2008'), ('14.5152'), ('0.8439'), ('9.7738'), ('8.8153'),
           ('0.9019'), ('1.9540'), ('1.8483'), ('0.9459'), ('0.2006'), ('0.2016'), ('1.0047'),
           ('15.6'), ('75.55'), ('29.87'), ('2.529'), ('1.0450'), ('0.9372'), ('1.0276'),
           ('0.9700'), ('1.0036'), ('1.0082'), ('0.9986'),
           -- Wave 5, the queue.
           ('2.5461'), ('2.5624'), ('2.5632'), ('2.5612'),
           ('0.6961'), ('1.1636'), ('4.3583'), ('3.0358'), ('1.1853'),
           ('6.7375'), ('2.3953'), ('0.9051'), ('1.9382'), ('0.7568'), ('1.5663'),
           ('2.5868'), ('0.6705'), ('1.1473'), ('4.4261'), ('6.9737'), ('2.4147'), ('0.8957'),
           ('1.293'), ('2.5540477739'),
           ('0.3752'), ('0.8486'), ('0.6295'), ('0.7264'), ('0.3207'), ('0.9925'), ('0.7956'),
           ('0.4925'), ('0.7408'), ('2.5957'), ('6.8417'), ('24.2435'), ('4.545'),
           ('0.2121'), ('0.7048'), ('0.9847'), ('0.9873'), ('0.4289'), ('0.9367'), ('0.9641'),
           ('0.2442'), ('0.6238'), ('0.8422'),
           ('216.6'), ('2.5318'), ('0.6441'), ('9.3057'), ('14.4486'), ('0.6925'), ('5.8781'),
           ('8.4879'), ('1.482'), ('6.362'), ('7.01'), ('20.23'), ('2.57'),
           -- Wave 6, the triage desk.
           ('10084'), ('0.1681'), ('0.4509'), ('22600'), ('0.3767'), ('0.5905'),
           ('27316'), ('0.4553'), ('0.9215'), ('4547'), ('5537'), ('16.81'),
           ('1.0383'), ('1.4916'), ('1.6401'), ('1.4095'), ('3.8716'), ('0.8883'),
           ('0.5941'), ('49.2'),
           ('99015.6062'), ('1.000000000000'),
           ('0.6957'), ('1.3640'), ('5.0720'), ('0.7042'), ('1.3984'), ('4.9970'),
           ('0.867'), ('1.0482'), ('0.257'),
           ('2.9201'), ('2.0174602407'),
           ('5.2657'), ('5.6603'), ('7.5822'), ('8.6627'), ('10.8461'), ('11.7533'),
           ('1.0749'), ('1.4399'), ('1.6451'), ('2.0598'), ('2.2321'),
           ('3.0691'), ('3.0240'), ('2.4900'), ('2.3160'), ('2.1891'), ('1.9622'),
           ('1.0385'), ('1.2675'), ('1.0800'), ('1.5278'), ('1.1739'), ('2.0280'),
           ('1.5883'), ('3.3826'), ('3.8580'), ('5.2470'), ('52.8'), ('0.62'),
           ('1.2381'), ('8.0768'), ('4.0797'), ('0.7353'), ('0.5024'), ('1.9904'),
           ('1.9797'), ('2.0497'),
           ('2.4512'), ('0.8046'), ('0.9303'), ('0.9982'), ('1.0016'), ('1.0544'),
           ('1.1157'), ('1.5632'), ('11.6'), ('56.3'),
           -- Wave 7, what triage costs.
           ('2.093'),
           ('0.7000'), ('0.9100'), ('0.4900'), ('0.8785'), ('0.7840'), ('0.9163'), ('0.8501'),
           ('0.9712'), ('0.9481'), ('0.9250'),
           ('0.7799'), ('0.8040'), ('0.8282'), ('0.8523'), ('0.9006'), ('0.9730'), ('26.3007'),
           ('0.16'),
           ('1.5789'), ('4.3030'), ('7.1449'), ('1.1868'), ('5.3872'), ('7.6569'), ('1.3364'),
           ('6.8672'), ('8.7071'), ('1.2124'), ('11.7301'), ('12.1307'), ('1.5938'), ('51.0349'),
           ('41.6458'), ('8.5145'),
           ('0.9135'), ('0.9790'), ('1.1133'), ('1.5510'), ('5.3248'),
           ('0.9629'), ('0.9268'), ('0.9112'), ('0.9451'), ('0.9874'),
           ('11.2'), ('11.3'), ('8.9'),
           -- Wave 8, the stopping rule.
           ('2.3810'), ('2.4352'), ('1.5747'), ('3.6572'), ('2.6283'), ('1.8143'),
           ('4.8597'), ('3.5532'), ('3.2911'), ('2.0158'),
           ('0.7872'), ('0.5590'), ('0.7307'), ('0.6789'), ('7.6623'), ('7.4580'),
           ('1.0144'), ('1.0216'), ('1.0439'), ('1.0569'), ('1.0128'),
           ('1.0015'), ('0.6461'), ('4.4'), ('1.4')
)
SELECT 'a headline figure is missing from the English README' AS failure, figure AS detail
FROM figures, english WHERE NOT contains(english.content, figure)

UNION ALL
SELECT 'a headline figure is missing from the Portuguese README', figure
FROM figures, portuguese
WHERE NOT contains(portuguese.content, replace(figure, '.', ','))

UNION ALL
-- A model or assertion file nothing links is a file nobody opens.
SELECT 'a sql model is not linked from the English README', file
FROM glob('sql/*.sql'), english WHERE NOT contains(english.content, file)
UNION ALL
SELECT 'a sql model is not linked from the Portuguese README', file
FROM glob('sql/*.sql'), portuguese WHERE NOT contains(portuguese.content, file)

UNION ALL
-- Wave 5 invents a queue as well as a funnel, so its class names are held to the same rule.
SELECT 'a declared priority class is not named in the disclaimer', priority
FROM queue_classes, disclaimer WHERE NOT contains(disclaimer.content, priority)
UNION ALL
SELECT 'a declared priority class label is not named in the disclaimer', label
FROM queue_classes, disclaimer WHERE NOT contains(disclaimer.content, label)
UNION ALL
-- Wave 6 declares two more things nobody measured, so the disclaimer has to say so in both languages.
SELECT 'the disclaimer does not declare the triage matrix as invented', phrase
FROM (VALUES ('confusion matrix'), ('matriz de confusão'),
             ('urgency weight'), ('peso de urgência')) AS t(phrase), disclaimer
WHERE NOT contains(disclaimer.content, phrase)

UNION ALL
-- And every discipline the READMEs argue about has to be one the parameters actually declare.
SELECT 'a declared queue discipline is not named in the English README', discipline
FROM (SELECT DISTINCT discipline FROM queue_disciplines), english
WHERE NOT contains(english.content, discipline)
UNION ALL
SELECT 'a declared queue discipline is not named in the Portuguese README', discipline
FROM (SELECT DISTINCT discipline FROM queue_disciplines), portuguese
WHERE NOT contains(portuguese.content, discipline)

UNION ALL
-- Every invented stage name has to be declared as invented, or the disclaimer is incomplete.
SELECT 'a declared stage is not named in the disclaimer', stage
FROM stages, disclaimer WHERE NOT contains(disclaimer.content, stage)
UNION ALL
SELECT 'a declared funnel is not named in the disclaimer', funnel
FROM funnels, disclaimer WHERE NOT contains(disclaimer.content, funnel)

UNION ALL
-- The two editions have to point at each other and at the disclaimer.
SELECT 'the English README does not link the Portuguese one', 'README.pt-BR.md'
FROM english WHERE NOT contains(content, 'README.pt-BR.md')
UNION ALL
SELECT 'the Portuguese README does not link the English one', 'README.md'
FROM portuguese WHERE NOT contains(content, '(README.md)')
UNION ALL
SELECT 'a README does not link the disclaimer', name
FROM docs WHERE name LIKE 'README%' AND NOT contains(content, 'DISCLAIMER.md')

UNION ALL
-- The roadmap has to say what is missing, not only what was built.
SELECT 'the roadmap does not say what is deliberately absent', 'section'
FROM docs WHERE name = 'docs/ROADMAP.md' AND NOT contains(content, 'What is deliberately not here')
UNION ALL
SELECT 'the roadmap does not say what is still open', 'section'
FROM docs WHERE name = 'docs/ROADMAP.md' AND NOT contains(content, 'Still open')

UNION ALL
-- And the count of recorded defects the READMEs quote, against the list that backs it.
SELECT 'the defect count quoted in a README does not match the roadmap', d.name
FROM docs d, recorded r, words w
WHERE d.name LIKE 'README%'
  AND w.n = r.defects
  AND NOT contains(d.content, CASE WHEN d.name = 'README.md' THEN w.english ELSE w.portuguese END)

UNION ALL
-- The counts the READMEs quote about the repository's own shape.
SELECT 'the English README does not quote the number of model files', 'models'
FROM english, (SELECT count(*) AS n FROM glob('sql/*.sql'))
WHERE n = 17 AND NOT contains(english.content, 'Seventeen model files')
UNION ALL
SELECT 'the English README does not quote the number of assertion files', 'assertions'
FROM english, (SELECT count(*) AS n FROM glob('tests/assert_*.sql'))
WHERE n = 17 AND NOT contains(english.content, 'seventeen assertion files')
UNION ALL
SELECT 'the Portuguese README does not quote the number of model files', 'models'
FROM portuguese, (SELECT count(*) AS n FROM glob('sql/*.sql'))
WHERE n = 17 AND NOT contains(portuguese.content, 'Dezessete arquivos de modelo')
UNION ALL
SELECT 'the Portuguese README does not quote the number of assertion files', 'assertions'
FROM portuguese, (SELECT count(*) AS n FROM glob('tests/assert_*.sql'))
WHERE n = 17 AND NOT contains(portuguese.content, 'dezessete de asserção')

UNION ALL
-- The repository's own code is written in English, and until wave 7 nothing checked it.
--
-- This file asserts that the two READMEs stay in step in both languages, and asserted nothing about the
-- language of the models and assertions themselves - so a parameters block written in Portuguese passed
-- every check in the suite. Defect 13. Only comment lines are examined, because the declared data is
-- deliberately Portuguese: the funnels, the stages and the class labels are invented Portuguese words, and
-- DISCLAIMER.md says so. The word list is restricted to function words that cannot occur inside an English
-- comment.
SELECT 'a comment in the repository''s own code is not in English', file || ': ' || trim(line) AS detail
FROM (
    SELECT filename AS file, unnest(string_split(content, chr(10))) AS line
    FROM read_text('sql/*.sql')
    UNION ALL
    SELECT filename, unnest(string_split(content, chr(10)))
    FROM read_text('tests/*.sql')
), (VALUES ('que'), ('não'), ('uma'), ('são'), ('para'), ('pelo'), ('pela'), ('isso'), ('cada'),
           ('dos'), ('das'), ('então'), ('também'), ('porque'), ('quando'), ('onde'), ('sobre'),
           ('mesmo'), ('apenas'), ('deve'), ('está'), ('pode'), ('foi')) AS w(word)
WHERE regexp_matches(line, '^\s*--')
  AND regexp_matches(lower(line), '\b' || w.word || '\b')

UNION ALL
SELECT 'a placeholder token survived in ' || name, token
FROM docs, (VALUES ('TODO'), ('FIXME'), ('XXX'), ('TKTK'), ('Lorem'), ('Placeholder')) AS t(token)
WHERE contains(content, token);
