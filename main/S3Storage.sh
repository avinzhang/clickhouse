#!/bin/bash

num_of_shards=1
num_of_replicas=2
dc_template=docker-compose-s3.yml
config_template=config-s3.xml
python3 create_config.py -s $num_of_shards -r $num_of_replicas -t $dc_template -c $config_template
num_of_nodes=$((num_of_shards * num_of_replicas))
ch_nodes=""
i=1
while [ $i -le $num_of_nodes ]
  do
    ch_nodes=`echo $ch_nodes | sed -e "s/$/ clickhouse0$i/"`
    i=$(( $i + 1 ))
done
echo

echo "* Start Minio"
docker-compose up -d --build --no-deps minio create-buckets

sleep 5
echo "  Create bucket"
mc config host add myminio http://localhost:8000 minio minio123
mc admin info myminio
mc mb myminio/mys3bucket
mc ls myminio/mys3bucket


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


echo "* Create table"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
CREATE TABLE s3_table1
(
  id UInt64,
  column1 String
)
ENGINE = MergeTree
ORDER BY id
SETTINGS storage_policy = 's3_main';
"

echo "  Insert some rows"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
INSERT INTO s3_table1 (id, column1)
VALUES (1, 'abc'), (2, 'xyz');
"

echo "* List the bucket"
mc ls myminio/mys3bucket
