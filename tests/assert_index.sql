-- The index against the repository it indexes.
--
-- An index is a document that stops being true silently. It survives a file being renamed, a report being
-- added, a figure being corrected in one place, and a whole wave being written - and in every one of
-- those cases it keeps rendering, keeps looking authoritative, and sends the reader to the wrong place.
-- That is the same failure mode as a figure quoted in prose, which this repository has compiled since
-- wave 1, and there is no reason the table of contents should be the one document nobody checks.
--
-- So: the declared rows of sql/g0_index.sql have to partition the directories exactly, every path in them
-- has to exist, every figure has to be one the build already holds to both READMEs, and both editions of
-- docs/FINDINGS.md have to contain every claim, every figure in their own decimal spelling, and every path.
WITH english AS (SELECT content FROM read_text('docs/FINDINGS.md')),
portuguese AS (SELECT content FROM read_text('docs/FINDINGS.pt-BR.md')),
figures_file AS (SELECT content FROM read_text('tests/assert_documents.sql')),
readme_en AS (SELECT content FROM read_text('README.md')),
readme_pt AS (SELECT content FROM read_text('README.pt-BR.md'))

-- Coverage, in both directions. A model or an assertion is either behind a finding or declared as
-- foundation; never neither, never both.
SELECT 'a model file is neither indexed nor declared as foundation' AS failure, file AS detail
FROM glob('sql/*.sql')
WHERE file NOT IN (SELECT model_file FROM index_findings)
  AND file NOT IN (SELECT model_file FROM index_foundation)

UNION ALL
SELECT 'a model file is both indexed and declared as foundation', file
FROM glob('sql/*.sql')
WHERE file IN (SELECT model_file FROM index_findings)
  AND file IN (SELECT model_file FROM index_foundation)

UNION ALL
SELECT 'an assertion file is neither indexed nor declared as a discipline check', file
FROM glob('tests/assert_*.sql')
WHERE file NOT IN (SELECT assertion_file FROM index_findings)
  AND file NOT IN (SELECT assertion_file FROM index_discipline)

UNION ALL
SELECT 'an assertion file is both indexed and declared as a discipline check', file
FROM glob('tests/assert_*.sql')
WHERE file IN (SELECT assertion_file FROM index_findings)
  AND file IN (SELECT assertion_file FROM index_discipline)

UNION ALL
-- Reports are a bijection with findings: a reader who wants to see a finding is told which query prints
-- it, and a report the index cannot reach is a report nobody runs.
SELECT 'a report is not reachable from the index', file
FROM glob('docs/report_*.sql')
WHERE file NOT IN (SELECT report_file FROM index_findings)

UNION ALL
SELECT 'two findings point at the same report', report_file
FROM (SELECT report_file, count(*) AS n FROM index_findings GROUP BY 1) WHERE n > 1

UNION ALL
-- Every declared path exists. This is the assertion that catches a rename.
SELECT 'an indexed model file does not exist', model_file
FROM index_findings WHERE model_file NOT IN (SELECT file FROM glob('sql/*.sql'))
UNION ALL
SELECT 'an indexed assertion file does not exist', assertion_file
FROM index_findings WHERE assertion_file NOT IN (SELECT file FROM glob('tests/assert_*.sql'))
UNION ALL
SELECT 'an indexed report file does not exist', report_file
FROM index_findings WHERE report_file NOT IN (SELECT file FROM glob('docs/report_*.sql'))
UNION ALL
SELECT 'a foundation model file does not exist', model_file
FROM index_foundation WHERE model_file NOT IN (SELECT file FROM glob('sql/*.sql'))
UNION ALL
SELECT 'a discipline assertion file does not exist', assertion_file
FROM index_discipline WHERE assertion_file NOT IN (SELECT file FROM glob('tests/assert_*.sql'))

UNION ALL
-- Structure. Every theme has findings, every finding has a theme, and the positions inside a theme are
-- contiguous from one, so a deleted row leaves a hole the build sees.
SELECT 'a declared theme carries no finding', theme
FROM index_themes WHERE theme NOT IN (SELECT theme FROM index_findings)
UNION ALL
SELECT 'a finding names a theme that is not declared', theme
FROM index_findings WHERE theme NOT IN (SELECT theme FROM index_themes)
UNION ALL
SELECT 'the positions inside a theme are not contiguous from one', theme
FROM (SELECT theme, count(*) AS n, min(position) AS lo, max(position) AS hi,
             count(DISTINCT position) AS distinct_positions
      FROM index_findings GROUP BY 1)
WHERE lo <> 1 OR hi <> n OR distinct_positions <> n

UNION ALL
-- Every wave the roadmap completed is indexed. This is what a new wave trips over if nobody indexes it:
-- the roadmap's own `## Wave N` headings are counted, and a wave with no finding fails.
SELECT 'a wave recorded in the roadmap has no indexed finding', 'wave ' || w.wave
FROM (
    SELECT DISTINCT cast(regexp_extract(marker, '\d+') AS INTEGER) AS wave
    FROM (SELECT unnest(regexp_extract_all(content, '(?m)^## Wave \d+')) AS marker
          FROM read_text('docs/ROADMAP.md'))
) w
WHERE w.wave NOT IN (SELECT wave FROM index_findings)

UNION ALL
SELECT 'an indexed finding names a wave the roadmap does not record', 'wave ' || f.wave
FROM (SELECT DISTINCT wave FROM index_findings) f
WHERE f.wave NOT IN (
    SELECT DISTINCT cast(regexp_extract(marker, '\d+') AS INTEGER)
    FROM (SELECT unnest(regexp_extract_all(content, '(?m)^## Wave \d+')) AS marker
          FROM read_text('docs/ROADMAP.md'))
)

UNION ALL
-- Every figure the index quotes is one the build already holds to both READMEs, so the index inherits
-- that guarantee instead of introducing a second, unchecked copy of a number.
SELECT 'an indexed figure is not one the build pins to both READMEs', figure
FROM index_findings, figures_file
WHERE NOT contains(figures_file.content, '(''' || figure || ''')')

UNION ALL
-- Both editions have to carry every claim, path and figure. The figures are checked in each language's
-- own decimal spelling, which is the rule wave 1 established for the READMEs.
SELECT 'a claim is missing from the English index', left(claim_en, 60)
FROM index_findings, english WHERE NOT contains(english.content, claim_en)
UNION ALL
SELECT 'a claim is missing from the Portuguese index', left(claim_pt, 60)
FROM index_findings, portuguese WHERE NOT contains(portuguese.content, claim_pt)
UNION ALL
SELECT 'a figure is missing from the English index', figure
FROM index_findings, english WHERE NOT contains(english.content, figure)
UNION ALL
SELECT 'a figure is missing from the Portuguese index', figure
FROM index_findings, portuguese WHERE NOT contains(portuguese.content, replace(figure, '.', ','))
UNION ALL
SELECT 'a path is missing from an index edition', d.name || ': ' || p.path
FROM (SELECT 'docs/FINDINGS.md' AS name, content FROM english
      UNION ALL SELECT 'docs/FINDINGS.pt-BR.md', content FROM portuguese) d,
     (SELECT model_file AS path FROM index_findings
      UNION SELECT assertion_file FROM index_findings
      UNION SELECT report_file FROM index_findings) p
WHERE NOT contains(d.content, p.path)

UNION ALL
-- The two editions point at each other and at the rest of the repository, and both READMEs point back.
SELECT 'the English index does not link the Portuguese one', 'FINDINGS.pt-BR.md'
FROM english WHERE NOT contains(content, 'FINDINGS.pt-BR.md')
UNION ALL
SELECT 'the Portuguese index does not link the English one', 'FINDINGS.md'
FROM portuguese WHERE NOT contains(content, '(FINDINGS.md)')
UNION ALL
SELECT 'an index edition does not link the roadmap', d.name
FROM (SELECT 'docs/FINDINGS.md' AS name, content FROM english
      UNION ALL SELECT 'docs/FINDINGS.pt-BR.md', content FROM portuguese) d
WHERE NOT contains(d.content, 'ROADMAP.md')
UNION ALL
SELECT 'an index edition does not link its own declared source', d.name
FROM (SELECT 'docs/FINDINGS.md' AS name, content FROM english
      UNION ALL SELECT 'docs/FINDINGS.pt-BR.md', content FROM portuguese) d
WHERE NOT contains(d.content, 'sql/g0_index.sql') OR NOT contains(d.content, 'tests/assert_index.sql')
UNION ALL
SELECT 'the English README does not link the index', 'docs/FINDINGS.md'
FROM readme_en WHERE NOT contains(content, 'docs/FINDINGS.md')
UNION ALL
SELECT 'the Portuguese README does not link the index', 'docs/FINDINGS.pt-BR.md'
FROM readme_pt WHERE NOT contains(content, 'docs/FINDINGS.pt-BR.md')

UNION ALL
-- And the claims are in the language they say they are. The English column is checked against the same
-- Portuguese function words wave 7's defect produced, which is the cheapest test there is for a bilingual
-- pair of documents drifting into one language.
SELECT 'an English claim contains a Portuguese function word', left(f.claim_en, 60)
FROM index_findings f,
     (VALUES ('que'), ('não'), ('uma'), ('são'), ('para'), ('pelo'), ('pela'), ('isso'), ('cada'),
             ('dos'), ('das'), ('então'), ('também'), ('porque'), ('quando'), ('onde'), ('sobre'),
             ('mesmo'), ('apenas'), ('deve'), ('está'), ('pode'), ('foi')) AS w(word)
-- \b rather than a lookbehind, because DuckDB's regex engine is RE2 and has none. That is safe for
-- exactly these words: none of them ends in punctuation, which is where \b stops working.
WHERE regexp_matches(lower(f.claim_en), '\b' || w.word || '\b')
