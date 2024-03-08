#!/bin/bash

#XML configs for keepers and clickhouse nodes.  
#By default, 3 keepers, 1 shard, 2 replicas
#To change, see help: python3 create_config.py --help
num_of_shards=3
num_of_replicas=2
python3 create_config.py -s $num_of_shards -r $num_of_replicas
num_of_nodes=$((num_of_shards * num_of_replicas))
init_node=clickhouse01
nodes=""
i=2
while [ $i -le 6 ]
  do
    nodes=`echo $init_node | sed -e "s/$/ clickhouse0$i/"`
    init_node=$nodes
    i=$(( $i + 1 ))
done
echo
echo "* Start keepers"
docker-compose up -d --build --no-deps keeper01 keeper02 keeper03


KEEPERS_STARTED=false
while [ "$KEEPERS_STARTED" = "false" ]
do
    echo " Waiting for Keepers to start..."
    keeper01_status=`docker-compose exec keeper01 bash -c "echo ruok |nc localhost 9181"`
    keeper02_status=`docker-compose exec keeper02 bash -c "echo ruok |nc localhost 9181"`
    keeper03_status=`docker-compose exec keeper03 bash -c "echo ruok |nc localhost 9181"`
    if [ "$keeper01_status" = "imok" ] && [ "$keeper02_status" = "imok" ] && [ "$keeper03_status" = "imok" ]; then
       echo " Keepers are started and ready"
       KEEPERS_STARTED=true
    fi
    sleep 5
done
echo
echo "* Start clickhouse nodes"
docker-compose up -d --build --no-deps $nodes
echo
sleep 5
echo "* Create database"
createdb=$(echo "create database db1 on cluster cluster_$(echo $num_of_shards)S_$(echo $num_of_replicas)R")
docker exec -it clickhouse01 clickhouse-client -h localhost -q"
$createdb
"
echo
echo
echo " create RMT table"
create_RMT_table="CREATE TABLE db1.events on cluster 'cluster_$(echo $num_of_shards)S_$(echo $num_of_replicas)R'
(
    time DateTime,
    uid Int64,
    type LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/cluster_2S_3R/{shard}/events', '{replica}')
PARTITION BY toDate(time)
ORDER BY uid;
"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
$create_RMT_table
"

echo
echo " Create dist table"
create_dist_table="CREATE TABLE db1.dist_table ON CLUSTER 'cluster_$(echo $num_of_shards)S_$(echo $num_of_replicas)R'
  AS db1.events
  ENGINE = Distributed('cluster_$(echo $num_of_shards)S_$(echo $num_of_replicas)R', db1, events, rand());
"

docker exec -it clickhouse01 clickhouse-client -h localhost -q "
$create_dist_table
"
echo
sleep 3
echo "* Insert messages"
docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "
INSERT INTO db1.dist_table VALUES('2020-01-01 10:00:00', 100, 'view');
INSERT INTO db1.dist_table VALUES('2020-01-02 10:00:00', 200, 'view');
INSERT INTO db1.dist_table VALUES('2020-01-03 10:00:00', 300, 'view');
INSERT INTO db1.dist_table VALUES('2020-01-04 10:00:00', 400, 'view');
INSERT INTO db1.dist_table VALUES('2020-01-05 10:00:00', 500, 'view');
INSERT INTO db1.dist_table VALUES('2020-01-06 10:00:00', 600, 'view');
INSERT INTO db1.dist_table VALUES('2020-01-07 10:00:00', 700, 'view');
INSERT INTO db1.dist_table VALUES('2020-01-08 10:00:00', 800, 'view');
INSERT INTO db1.dist_table VALUES('2020-01-09 10:00:00', 900, 'view');
"

sleep 3
echo " query table 1"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
select * from db1.dist_table settings send_logs_level = 'trace', load_balancing = 'round_robin', prefer_localhost_replica = '0';
"

echo
echo
echo " query table 2"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
select * from db1.dist_table settings send_logs_level = 'trace', load_balancing = 'round_robin', prefer_localhost_replica = '0';
"
echo
echo
echo " query table 3"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
select * from db1.dist_table settings send_logs_level = 'trace', load_balancing = 'round_robin', prefer_localhost_replica = '0' ;
"

echo
echo 
echo " * Show settings for the query" 
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
select Settings from clusterAllReplicas('cluster_$(echo $num_of_shards)S_$(echo $num_of_replicas)R', system.query_log) where query ilike 'select * from db1.dist_table%' and type = 'QueryFinish';
"
