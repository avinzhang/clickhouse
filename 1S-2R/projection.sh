CREATE DATABASE projection_demo;
USE projection_demo;

CREATE TABLE visits_order on CLUSTER 'cluster_1S_2R'
(
   `user_id` UInt64,
   `user_name` String,
   `pages_visited` Nullable(Float64),
   `user_agent` String
)
ENGINE = ReplicatedMergeTree()
PRIMARY KEY user_agent;

ALTER TABLE visits_order ADD PROJECTION user_name_projection (
SELECT
*
ORDER BY user_name
);

ALTER TABLE visits_order MATERIALIZE PROJECTION user_name_projection;

INSERT INTO visits_order SELECT
    number,
    'john',
    1.5 * (number / 2),
    'Android'
FROM numbers(1, 1000000);

INSERT INTO visits_order SELECT
    number,
    'tim',
    1.5 * (number / 2),
    'Android'
FROM numbmers(1, 1000000);

INSERT INTO visits_order SELECT
    number,
    'ben',
    1.5 * (number / 2),
    'Android'
FROM numbmers(1, 1000000);


SELECT
    *
FROM visits_order
WHERE user_name='test'
LIMIT 2;

SELECT query, projections FROM system.query_log WHERE query_id='<query_id>'


#show storage used
SELECT
    table,
    formatReadableSize(sum(bytes)) AS size
FROM system.parts
WHERE active AND (table LIKE 'visits_order')
GROUP BY table
