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
mc mb myminio/mys3bucket/mymessage
mc ls myminio/mys3bucket

echo "* Starting up clickhouse keepers"
docker-compose up -d --build --no-deps keeper01 keeper02 keeper03


KEEPERS_STARTED=false
while [ "$KEEPERS_STARTED" = "false" ]
do
    echo "   Waiting for Keepers to start..."
    keeper01_status=`echo ruok |nc localhost 9181`
    keeper02_status=`echo ruok |nc localhost 9181`
    keeper03_status=`echo ruok |nc localhost 9181`
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
echo

echo "* Create S3Queue table engine"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
CREATE TABLE s3queue_engine_table (trade_time DateTime, volume int)
    ENGINE=S3Queue('http://minio:8000/mys3bucket/mymessage/*.csv', minio, minio123, 'CSV')
    SETTINGS
        mode = 'unordered',
        s3queue_enable_logging_to_s3queue_log = 1,
        keeper_path = '/clickhouse/s3queue/';
"

echo "  Create backend table for materialized view"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
CREATE TABLE stock (trade_time DateTime, volume int)
    ENGINE = MergeTree() ORDER BY trade_time;
"
echo "  Create materialized view"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
CREATE MATERIALIZED VIEW stock_queue TO stock
    AS SELECT * FROM s3queue_engine_table;
"


echo "  Generate 5 csv files with random data and upload to minion"
i=1
while [ "$i" -le 3 ]
do
  truncate -s 0 /tmp/random$i.csv
  n=1
  while [ "$n" -le 10000 ]
  do
      printf "%04d-%02d-%02d %02d:%02d:%02d, %03d\n" $((2000 + RANDOM % 23)) $((RANDOM%12)) $((RANDOM%30)) $((RANDOM%24)) $((RANDOM%60)) $((RANDOM%60)) $((RANDOM%999)) >> /tmp/random$i.csv
      n=$(( $n+1 ))
  done
  mc cp /tmp/random$i.csv myminio/mys3bucket/mymessage
  i=$(( $i+1 ))
done
echo 
PROCESSED=false
while [ "$PROCESSED" = "false" ]
do
  grep "SystemLog (system.s3queue_log): Flushed system log" log/clickhouse01/clickhouse-server.log && PROCESSED=true
  echo "  Wait for processing..."
  sleep 5
done 
echo
echo "  See S3Queue log"
docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "
select file_name, rows_processed, status, processing_start_time, processing_end_time, timeDiff(processing_start_time, processing_end_time) as duration_s from system.s3queue_log order by processing_start_time DESC Format PrettyMonoBlock;
"

#Count the rows in stock table
#docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "from stock select count(), formatReadableQuantity(count()) as NiceCount, now() format PrettyNoEscapes;"
