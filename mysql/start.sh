#!/bin/bash

echo "* Generate configs for clickhouse nodes"
#for keepers
node=1
while [ $node -le 3 ]
do
  mkdir -p ./config/clickhouse0${node}
  node=$node envsubst < ./config/keeper.xml > ./config/clickhouse0${node}/keeper.xml
  node=$((node+1))
done
shard_id=1
replica_id=1
node=1
while [ $shard_id -le 2 ]
do
  while [ $replica_id -le 2 ]
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
echo
echo "* Create database"
docker exec -it clickhouse01 bash -c 'clickhouse-client -h localhost -q "CREATE DATABASE mysql ON CLUSTER 'cluster_2S_2R';"'
echo
echo "Create table on db1"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE TABLE mysql.student on cluster 'cluster_2S_2R'
(
    id UInt32,
    name String,
    age UInt32,
    created_at DateTime,
    updated_at DateTime
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/cluster_2S_2R/{shard}/student', '{replica}')
PARTITION BY toDate(created_at)
ORDER BY (id,name);
"

echo
echo "Create distributed table to represent the data on the shards"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE TABLE mysql.student_dist ON CLUSTER 'cluster_2S_2R'
  AS mysql.student
  ENGINE = Distributed('cluster_2S_2R', mysql, student, rand());
"
echo
echo "* Insert rows into table on node clickhouse01"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
INSERT into mysql.student_dist
SELECT *
FROM
   mysql(
    'mysql:3306',
    'mysqldb',
    'student',
    'root',
    'rootpass')
;
"
echo
echo "* Select data from clickhouse01 - Shard1"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from mysql.student;
"

echo "  Select rows from clickhouse02 - a replica of clickhouse01"
docker exec -it clickhouse02 clickhouse-client -h localhost -q "
select * from mysql.student;
"
echo
echo
echo "* Select rows from clickhouse03 - shard2"
docker exec -it clickhouse03 clickhouse-client -h localhost -q "
select * from mysql.student;
"

echo "  Select rows from clickhouse04 - replica of clickhouse03"
docker exec -it clickhouse04 clickhouse-client -h localhost -q "
select * from mysql.student;
"
echo
echo
echo "* Read from distributed table"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from mysql.student_dist;
"
