#!/bin/bash

echo "Start the cluster"
docker-compose up -d

echo "Create database"
docker exec -it clickhouse01 bash -c 'clickhouse-client -h localhost -q "CREATE DATABASE db1 ON CLUSTER 'cluster_2S_2R';"'

echo "List created shards and replicas"
docker exec -it clickhouse01 bash -c 'clickhouse-client -h localhost -q "
SELECT
    cluster,
    shard_num,
    replica_num
FROM system.clusters
WHERE cluster = '"'cluster_2S_2R'"'
ORDER BY
    shard_num ASC,
    replica_num ASC;
"'

echo "Create table on db1"
docker exec -it clickhouse01 bash -c 'clickhouse-client -h localhost -q "
CREATE TABLE db1.table1 on cluster 'cluster_2S_2R'
(
    id UInt64,
    column1 String
)
ENGINE = MergeTree
ORDER BY column1;
"'

echo "Insert rows into table1 on node clickhouse01"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
INSERT INTO db1.table1
    (id, column1)
VALUES
    (1, 'abc'),
    (2, 'def')
"

echo "Insert rows into table1 on node clickhouse04"
docker exec -it clickhouse04 clickhouse-client -h localhost -q "
INSERT INTO db1.table1
    (id, column1)
VALUES
    (3, 'ghi'),
    (4, 'jkl')
"

echo "Select rows from clickhouse01"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from db1.table1;
"

echo "Select rows from clickhouse04"
docker exec -it clickhouse04 clickhouse-client -h localhost -q "
select * from db1.table1;
"

echo "Create distributed table to represent the data on the two shards"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE TABLE db1.dist_table (
    id UInt64,
    column1 String
)
ENGINE = Distributed(cluster_2S_2R,db1,table1);
"

echo "Read from distributed table"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from db1.dist_table;
"

