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
means AS (SELECT s, avg(u01(i, s)) AS m FROM draws GROUP BY s),
-- The eleven streams above are eleven arbitrary salts, and the repository does not draw from them. It
-- draws from seven: 7 and 101 for the funnel walk, 613 for the frailty class, 977 for the archiving
-- decision, and 1301, 1409 and 1511 for the queue's arrivals, classes and handling times. Defect 1 in
-- docs/ROADMAP.md is that the uniformity of one stream says nothing about the independence of two, and this
-- is the same sentence one level up: the independence of eleven streams nobody uses says nothing about the
-- independence of the seven that carry every figure. So those twenty-one pairs are checked by name.
used(salt) AS (VALUES (7), (101), (613), (977), (1301), (1409), (1511)),
used_pairs AS (
    SELECT a.salt AS sa, b.salt AS sb, corr(u01(d.i, a.salt), u01(d.i, b.salt)) AS c
    FROM range(1, 100001) d(i), used a, used b
    WHERE a.salt < b.salt GROUP BY 1, 2
)
SELECT 'a decile is more than 2% away from a tenth' AS failure, bucket::VARCHAR AS detail, n::DOUBLE AS value
FROM deciles WHERE abs(n / 50000.0 - 1.0) > 0.02

UNION ALL
SELECT 'two streams correlate above 0.02', sa || ' vs ' || sb, round(c, 5)
FROM pairs WHERE abs(c) > 0.02

UNION ALL
SELECT 'two streams the repository actually draws from correlate above 0.02', sa || ' vs ' || sb,
       round(c, 5)
FROM used_pairs WHERE abs(c) > 0.02

UNION ALL
SELECT 'a stream the repository actually draws from has a mean more than 0.005 from a half',
       salt::VARCHAR, round(m, 5)
FROM (SELECT salt, avg(u01(i, salt)) AS m FROM range(1, 200001) t(i), used GROUP BY 1)
WHERE abs(m - 0.5) > 0.005

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
