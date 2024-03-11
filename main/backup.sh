#!/bin/bash

num_of_shards=1
num_of_replicas=2
config_template=config-backup.xml
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

echo " Create table partitioned with date, insert into the table"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
CREATE TABLE partitioned
(
    t Date, 
    label UInt8, 
    value UInt32
)
ENGINE = MergeTree 
PARTITION BY t ORDER BY label;

INSERT INTO partitioned SELECT today() - rand32() % 10, rand32() % 10000, rand32() FROM numbers(1000000);
"

echo " Select partitions and size from the table"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
SELECT partition, formatReadableSize(sum(bytes))
FROM system.parts
WHERE table = 'partitioned'
GROUP BY partition;
"


echo "Backup a partition" 
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
backup table partitioned partition '2024-03-10' to Disk('backups','2.zip');
"

