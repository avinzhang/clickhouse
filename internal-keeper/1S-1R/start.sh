#!/bin/bash

echo "* Generate configs for clickhouse nodes"
#for keepers
node=1
while [ $node -le 1 ]
do
  mkdir -p ./config/clickhouse0${node}
  node=$node envsubst < ./config/keeper.xml > ./config/clickhouse0${node}/keeper.xml
  node=$((node+1))
done
shard_id=1
replica_id=1
node=1
while [ $shard_id -le 1 ]
do
  while [ $replica_id -le 1 ]
  do
     mkdir -p ./config/clickhouse0${node}/
     node=$node replica_id=$replica_id shard_id=$shard_id envsubst < ./config/config.xml > ./config/clickhouse0${node}/config.xml
     node=$((node+1))
     replica_id=$((replica_id+1))
  done
  shard_id=$((shard_id+1))
  replica_id=1
done
echo
echo "* Generate users.xml"
envsubst < ./config/users.xml > ./config/users/users.xml
echo
echo "Start the cluster"
docker-compose up -d
sleep 5
echo
echo "* Check clickhouse system.zookeeper table"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from system.zookeeper 
where path IN ('/', '/clickhouse')
"
exit
echo
echo
echo "* Create database"
docker exec -it clickhouse01 bash -c 'clickhouse-client -h localhost -q "CREATE DATABASE db1 ON CLUSTER 'cluster_2S_2R';"'
echo
echo
echo "* List created shards and replicas"
docker exec -it clickhouse01 bash -c 'clickhouse-client -h localhost -q "
SELECT
    cluster,
    host_name,
    shard_num,
    replica_num
FROM system.clusters
WHERE cluster = '"'cluster_2S_2R'"'
ORDER BY
    shard_num ASC,
    replica_num ASC;
"'
echo
echo "Create table on db1"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE TABLE db1.events on cluster 'cluster_2S_2R'
(
    time DateTime,
    uid Int64,
    type LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/cluster_2S_2R/{shard}/events', '{replica}')
PARTITION BY toDate(time)
ORDER BY uid;
"

echo
echo "Create distributed table to represent the data on the shards"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE TABLE db1.dist_table ON CLUSTER 'cluster_2S_2R'
  AS db1.events
  ENGINE = Distributed('cluster_2S_2R', db1, events, rand());
"
echo
echo "* Insert rows into table on node clickhouse01"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
INSERT INTO db1.dist_table VALUES
    ('2020-01-01 10:00:00', 100, 'view'),
    ('2020-01-01 10:05:00', 101, 'view'),
    ('2020-01-01 11:00:00', 100, 'contact'),
    ('2020-01-01 12:10:00', 101, 'view'),
    ('2020-01-02 08:10:00', 100, 'view'),
    ('2020-01-03 13:00:00', 103, 'view');
"
echo
echo "* Select data from clickhouse01 - Shard1"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from db1.events;
"

echo "  Select rows from clickhouse02 - a replica of clickhouse01"
docker exec -it clickhouse02 clickhouse-client -h localhost -q "
select * from db1.events;
"
echo
echo
echo "* Select rows from clickhouse03 - shard2"
docker exec -it clickhouse03 clickhouse-client -h localhost -q "
select * from db1.events;
"

echo "  Select rows from clickhouse04 - replica of clickhouse03"
docker exec -it clickhouse04 clickhouse-client -h localhost -q "
select * from db1.events;
"
echo
echo
echo "* Read from distributed table"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from db1.dist_table;
"
exit
echo 
echo
echo
echo "Create uk_price_paid table"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE TABLE db1.uk_price_paid on CLUSTER 'cluster_2S_2R'
(
    price UInt32,
    date Date,
    postcode1 LowCardinality(String),
    postcode2 LowCardinality(String),
    type Enum8('terraced' = 1, 'semi-detached' = 2, 'detached' = 3, 'flat' = 4, 'other' = 0),
    is_new UInt8,
    duration Enum8('freehold' = 1, 'leasehold' = 2, 'unknown' = 0),
    addr1 String,
    addr2 String,
    street LowCardinality(String),
    locality LowCardinality(String),
    town LowCardinality(String),
    district LowCardinality(String),
    county LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/cluster_2S_2R/{shard}/uk_price_paid_dist', '{replica}')
ORDER BY (postcode1, postcode2, addr1, addr2);
"
echo
echo "create uk_price_paid_dist table"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE TABLE db1.uk_price_paid_dist ON CLUSTER 'cluster_2S_2R'
  AS db1.uk_price_paid
  ENGINE = Distributed('cluster_2S_2R', db1, uk_price_paid, rand());
"

echo
echo "Insert data"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
INSERT INTO db1.uk_price_paid_dist
WITH
   splitByChar(' ', postcode) AS p
SELECT
    toUInt32(price_string) AS price,
    parseDateTimeBestEffortUS(time) AS date,
    p[1] AS postcode1,
    p[2] AS postcode2,
    transform(a, ['T', 'S', 'D', 'F', 'O'], ['terraced', 'semi-detached', 'detached', 'flat', 'other']) AS type,
    b = 'Y' AS is_new,
    transform(c, ['F', 'L', 'U'], ['freehold', 'leasehold', 'unknown']) AS duration,
    addr1,
    addr2,
    street,
    locality,
    town,
    district,
    county
FROM url(
    'http://prod.publicdata.landregistry.gov.uk.s3-website-eu-west-1.amazonaws.com/pp-complete.csv',
    'CSV',
    'uuid_string String,
    price_string String,
    time String,
    postcode String,
    a String,
    b String,
    c String,
    addr1 String,
    addr2 String,
    street String,
    locality String,
    town String,
    district String,
    county String,
    d String,
    e String'
) SETTINGS max_http_get_redirects=10;
"

docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select formatReadableQuantity(count()) from db1.uk_price_paid
"
