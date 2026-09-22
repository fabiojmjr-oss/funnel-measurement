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
           (7, 'Seven so far', 'Sete até aqui'), (8, 'Eight so far', 'Oito até aqui')
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
           ('19.911'), ('24.231'), ('13.257'), ('0.139'), ('3.183'), ('0.6817'), ('0.1047')
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
WHERE n = 7 AND NOT contains(english.content, 'Seven model files')
UNION ALL
SELECT 'the English README does not quote the number of assertion files', 'assertions'
FROM english, (SELECT count(*) AS n FROM glob('tests/assert_*.sql'))
WHERE n = 9 AND NOT contains(english.content, 'nine assertion files')
UNION ALL
SELECT 'the Portuguese README does not quote the number of model files', 'models'
FROM portuguese, (SELECT count(*) AS n FROM glob('sql/*.sql'))
WHERE n = 7 AND NOT contains(portuguese.content, 'Sete arquivos de modelo')
UNION ALL
SELECT 'the Portuguese README does not quote the number of assertion files', 'assertions'
FROM portuguese, (SELECT count(*) AS n FROM glob('tests/assert_*.sql'))
WHERE n = 9 AND NOT contains(portuguese.content, 'nove de asserção')

UNION ALL
SELECT 'a placeholder token survived in ' || name, token
FROM docs, (VALUES ('TODO'), ('FIXME'), ('XXX'), ('TKTK'), ('Lorem'), ('Placeholder')) AS t(token)
WHERE contains(content, token);
