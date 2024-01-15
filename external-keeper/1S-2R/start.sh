#!/bin/bash

echo "Start the cluster"
docker-compose up -d

sleep 5
echo
echo "* Check clickhouse system.zookeeper table"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from system.zookeeper 
where path IN ('/', '/clickhouse')
"
echo
echo
echo "* Create database"
docker exec -it clickhouse01 bash -c 'clickhouse-client -h localhost -q "CREATE DATABASE db1 ON CLUSTER 'cluster_1S_2R';"'
echo
echo
echo "* List created shards and replicas"
docker exec -it clickhouse01 bash -c 'clickhouse-client -h localhost -q "
SELECT
    cluster,
    shard_num,
    replica_num
FROM system.clusters
WHERE cluster = '"'cluster_1S_2R'"'
ORDER BY
    shard_num ASC,
    replica_num ASC;
"'

echo "Create table on db1"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE TABLE db1.events on cluster 'cluster_1S_2R'
(
    time DateTime,
    uid Int64,
    type LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/cluster_1S_2R/{shard}/events', '{replica}')
PARTITION BY toDate(time)
ORDER BY uid;
"


echo "Create distributed table to represent the data on the shards"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE TABLE db1.dist_table ON CLUSTER 'cluster_1S_2R'
  AS db1.events
  ENGINE = Distributed('cluster_1S_2R', db1, events, rand());
"


echo "Insert rows into table on node clickhouse01"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
INSERT INTO db1.dist_table VALUES
    ('2020-01-01 10:00:00', 100, 'view'),
    ('2020-01-01 10:05:00', 101, 'view'),
    ('2020-01-01 11:00:00', 100, 'contact'),
    ('2020-01-01 12:10:00', 101, 'view'),
    ('2020-01-02 08:10:00', 100, 'view'),
    ('2020-01-03 13:00:00', 103, 'view');
"

echo "Select data from clickhouse01"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from db1.events;
"

echo "Select rows from clickhouse02"
docker exec -it clickhouse02 clickhouse-client -h localhost -q "
select * from db1.events;
"

echo "Read from distributed table"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from db1.dist_table;
"
echo 
exit
