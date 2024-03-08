#!/bin/bash

num_of_shards=1
num_of_replicas=2
dc_template=docker-compose-mysql.yml
python3 create_config.py -s $num_of_shards -r $num_of_replicas -t $dc_template
num_of_nodes=$((num_of_shards * num_of_replicas))
ch_nodes=""
i=1
while [ $i -le $num_of_nodes ]
  do
    ch_nodes=`echo $ch_nodes | sed -e "s/$/ clickhouse0$i/"`
    i=$(( $i + 1 ))
done
echo
echo "* Start mysql"
docker-compose up -d --build --no-deps mysql
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
sleep 5
echo
echo
echo "Create table "
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE TABLE student 
(
    id UInt32,
    name String,
    age UInt32,
    created_at DateTime,
    updated_at DateTime
)
ENGINE = MergeTree()
PARTITION BY toDate(created_at)
ORDER BY (id,name);
"

echo
echo "* Insert rows into table on node clickhouse01"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
INSERT into student
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
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from student;
"

