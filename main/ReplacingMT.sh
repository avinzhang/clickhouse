#!/bin/bash

num_of_shards=1
num_of_replicas=2
python3 create_config.py -s $num_of_shards -r $num_of_replicas
num_of_nodes=$((num_of_shards * num_of_replicas))
ch_nodes=""
i=1
while [ $i -le $num_of_nodes ]
  do
    ch_nodes=`echo $ch_nodes | sed -e "s/$/ clickhouse0$i/"`
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
docker-compose up -d --build --no-deps $ch_nodes
echo
CLICKHOUSE_STARTED=false
while [ "$CLICKHOUSE_STARTED" = "false" ]
do
    echo "   Waiting for Clickhouse nodes to start..."
    for i in $(seq 0 $((num_of_nodes-1)))
    do
      clickhousenode_status=`curl -s http://localhost:$((i+8123))`
      echo "    http port $((i+8123)) is $clickhousenode_status"
      if [ "$clickhousenode_status" != "Ok." ]; then
        CLICKHOUSE_STARTED=false
        break
      else
        CLICKHOUSE_STARTED=true
      fi
    done
    if [ $CLICKHOUSE_STARTED = "true" ]; then
      echo "   Clickhouse nodes are started and ready"
    fi
    sleep 5
done

echo "* Create Replacing MergeTree Table"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE OR REPLACE TABLE hits
(
    id UInt32,
    url String,
    visits UInt32,
    timestamp DateTime
) ENGINE = ReplacingMergeTree
ORDER By id;
"

echo "  Insert some data"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
INSERT INTO hits VALUES (100, '/index', 500, now()) (200, '/docs', 10000, now()) (300, '/learn', 2000, now());
"

echo "* Select from table"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from hits;
"
echo
echo
echo "*  Insert more values for id 100 and 300"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
INSERT INTO hits VALUES (100, '/index', 600, now()) (300, '/learn', 3000, now());
"

