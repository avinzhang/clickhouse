#!/bin/bash

#XML configs for keepers and clickhouse nodes.  
#By default, 3 keepers, 1 shard, 2 replicas
#To change, see help: python3 create_config.py --help
num_of_shards=2
num_of_replicas=3
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
exit
docker exec -it clickhouse01 clickhouse-client -h localhost -q"
create database db1 on cluster 'cluster_2S_3R'
"

docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE TABLE db1.events on cluster 'cluster_2S_3R'
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
CREATE TABLE db1.dist_table ON CLUSTER 'cluster_2S_3R'
  AS db1.events
  ENGINE = Distributed('cluster_2S_3R', db1, events, rand());
"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
INSERT INTO db1.dist_table VALUES('2020-01-01 10:00:00', 100, 'view');
"


docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
set send_logs_level = 'trace';
select * from db1.events;
"
