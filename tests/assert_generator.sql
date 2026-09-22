-- The generator is the one thing every figure depends on, and its first version passed the obvious
-- test while being badly broken. So the assertions are the ones that would have caught it.
WITH draws AS (SELECT i, s FROM range(1, 100001) t(i), range(1, 12) u(s)),
deciles AS (
    SELECT least(9, floor(u01(i, 3) * 10))::INTEGER AS bucket, count(*) AS n
    FROM range(1, 500001) t(i) GROUP BY 1
),
pairs AS (
    SELECT a.s AS sa, b.s AS sb, corr(u01(d.i, a.s), u01(d.i, b.s)) AS c
    FROM range(1, 100001) d(i), range(1, 12) a(s), range(1, 12) b(s)
    WHERE a.s < b.s GROUP BY 1, 2
),
means AS (SELECT s, avg(u01(i, s)) AS m FROM draws GROUP BY s)
SELECT 'a decile is more than 2% away from a tenth' AS failure, bucket::VARCHAR AS detail, n::DOUBLE AS value
FROM deciles WHERE abs(n / 50000.0 - 1.0) > 0.02

UNION ALL
SELECT 'two streams correlate above 0.02', sa || ' vs ' || sb, round(c, 5)
FROM pairs WHERE abs(c) > 0.02

UNION ALL
SELECT 'a stream mean is more than 0.005 from a half', s::VARCHAR, round(m, 5)
FROM means WHERE abs(m - 0.5) > 0.005

UNION ALL
SELECT 'consecutive draws of one stream correlate above 0.02', 'lag one', round(c, 5)
FROM (SELECT corr(u01(i, 5), u01(i + 1, 5)) AS c FROM range(1, 200001) t(i))
WHERE abs(c) > 0.02

UNION ALL
SELECT 'the uniform left the unit interval', 'range', v
FROM (SELECT min(u01(i, 9)) AS v FROM range(1, 200001) t(i)) WHERE v < 0.0
UNION ALL
SELECT 'the uniform left the unit interval', 'range', v
FROM (SELECT max(u01(i, 9)) AS v FROM range(1, 200001) t(i)) WHERE v >= 1.0;
