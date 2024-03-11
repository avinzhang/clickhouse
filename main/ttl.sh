#!/bin/bash

num_of_shards=1
num_of_replicas=2
config_template=config-ttl.xml
python3 create_config.py -s $num_of_shards -r $num_of_replicas -c $config_template
num_of_nodes=$((num_of_shards * num_of_replicas))
ch_nodes=""
i=1
while [ $i -le $num_of_nodes ]
  do
    ch_nodes=`echo $ch_nodes | sed -e "s/$/ clickhouse0$i/"`
    i=$(( $i + 1 ))
done
echo

echo "* Starting up clickhouse keepers"
docker-compose up -d --build --no-deps keeper01 keeper02 keeper03


KEEPERS_STARTED=false
while [ "$KEEPERS_STARTED" = "false" ]
do
    echo "   Waiting for Keepers to start..."
    keeper01_status=`docker-compose exec keeper01 bash -c "echo ruok |nc localhost 9181"`
    keeper02_status=`docker-compose exec keeper02 bash -c "echo ruok |nc localhost 9181"`
    keeper03_status=`docker-compose exec keeper03 bash -c "echo ruok |nc localhost 9181"`
    if [ "$keeper01_status" = "imok" ] && [ "$keeper02_status" = "imok" ] && [ "$keeper03_status" = "imok" ]; then
       echo "  Keepers are started and ready"
       KEEPERS_STARTED=true
    fi
    sleep 5
done

echo "* Starting up clickhouse nodes"
docker-compose up -d --build --no-deps $ch_nodes

CLICKHOUSE_STARTED=false
while [ "$CLICKHOUSE_STARTED" = "false" ]
do
    echo "   Waiting for Clickhouse nodes to start..."
    clickhouse01_status=`curl -s http://localhost:8123`
    clickhouse02_status=`curl -s http://localhost:8124`
    if [ "$clickhouse01_status" == "Ok." ] && [ "$clickhouse02_status" == "Ok." ]; then
       echo "  Clickhouse nodes are started and ready"
       CLICKHOUSE_STARTED=true
    fi
    sleep 5
done

docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
create or replace table test
(
  time DateTime,
  number Int32,
  string String
)
Engine = MergeTree()
Primary Key time
TTL
  time TO VOLUME 'default',
  time + INTERVAL 20 SECOND TO VOLUME 'cold_volume';
"

#
#---
#ALTER TABLE test
#   MODIFY TTL
#      time TO VOLUME 'default',
#      time + INTERVAL 10 SECOND TO VOLUME 'warm_volume',
#      time + INTERVAL 20 SECOND TO VOLUME 'cold_volume';
#
#ALTER TABLE test
#    MATERIALIZE TTL;
#---
#
echo "Insert data"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
Insert into test
SELECT
  toUnixTimestamp(now()),
  floor(randNormal(1000, 5)),
  randomString(4)
FROM numbers(1);
"

" Select the diskname of the parts"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
SELECT
    name,
    disk_name
FROM system.parts
WHERE (table = 'test') AND (active = 1);
"


