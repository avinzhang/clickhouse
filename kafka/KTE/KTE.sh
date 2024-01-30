#!/bin/bash

docker-compose up -d --build --no-deps kafka keeper01 keeper02 keeper03


KEEPERS_STARTED=false
while [ "$KEEPERS_STARTED" = "false" ]
do
    echo "Waiting for Keepers to start..."
    keeper01_status=`docker-compose exec keeper01 bash -c "echo ruok |nc localhost 9181"`
    keeper02_status=`docker-compose exec keeper02 bash -c "echo ruok |nc localhost 9181"`
    keeper03_status=`docker-compose exec keeper03 bash -c "echo ruok |nc localhost 9181"`
    if [ "$keeper01_status" = "imok" ] && [ "$keeper02_status" = "imok" ] && [ "$keeper03_status" = "imok" ]; then
       echo "Keepers are started and ready"
       KEEPERS_STARTED=true
    fi
    sleep 5
done

docker-compose up -d --build --no-deps clickhouse01 clickhouse02


KAFKA_STARTED=false
while [ $KAFKA_STARTED == false ]
do
    docker-compose logs kafka | grep "Kafka Server started" &> /dev/null
    if [ $? -eq 0 ]; then
      KAFKA_STARTED=true
      echo "kafka is started and ready"
    else
      echo "Waiting for Kafka to start..."
    fi
    sleep 5
done


# Create kafka topic
echo "* Create kafka topic"
kafka-topics --bootstrap-server localhost:9092 --topic readings --create --replication-factor 1

# Produce messages to the topic
echo "* Produce messages to kafka topic using github.ndjson file"
kafka-console-producer --bootstrap-server localhost:9092 --topic readings <<END
1,"2020-05-16 23:55:44",14.2
2,"2020-05-16 23:55:45",21.1
3,"2020-05-16 23:55:51",12.9
4,"badmessage",12.3
5,"2020-05-16 23:56:01",11.5
END


echo "* Create github MergeTree table"
docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "
CREATE TABLE readings (
    readings_id Int32 Codec(DoubleDelta, LZ4),
    time DateTime Codec(DoubleDelta, LZ4),
    date ALIAS toDate(time),
    temperature Decimal(5,2) Codec(T64, LZ4)
) Engine = MergeTree
PARTITION BY toYYYYMM(time)
ORDER BY (readings_id, time);
"

#create kafka table engine
echo  "* Create kafka table engine"
docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "
CREATE TABLE readings_queue (
    readings_id Int32,
    time DateTime,
    temperature Decimal(5,2)
)
ENGINE = Kafka
SETTINGS kafka_broker_list = 'kafka:29092',
       kafka_topic_list = 'readings',
       kafka_group_name = 'readings_consumer_group',
       kafka_format = 'CSV',
       kafka_max_block_size = 1048576,
       kafka_handle_error_mode = 'stream', 
       kafka_skip_broken_messages = 0,
       kafka_thread_per_consumer = 0, 
       kafka_num_consumers = 1;
"

echo "* Create materialized view"
docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "
CREATE MATERIALIZED VIEW readings_queue_mv TO readings AS
SELECT * 
FROM readings_queue where length(_error) == 0;
"


# Write data from clickhouse to kafka"

echo "* Create topic github_error to store malformed messages returned from Clickhouse"
kafka-topics --bootstrap-server localhost:9092 --topic reading-error --create --replication-factor 1


echo " Create readings_out_queue kafka table to write to kafak topic"
docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "
CREATE TABLE readings_out_queue (
    topic String,
    partition Int64,
    offset Int64,
    raw String,
    error String
)
ENGINE = Kafka
SETTINGS kafka_broker_list = 'kafka:29092',
       kafka_topic_list = 'readings-error',
       kafka_group_name = 'readings_error_consumer_group',
       kafka_format = 'JSON',
       kafka_max_block_size = 1048576;
"

docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "
CREATE MATERIALIZED VIEW readings_out_queue_mv to readings_out_queue
   AS
   SELECT _topic AS topic,
               _partition AS partition,
               _offset AS offset,
               _raw_message AS raw,
               _error AS error
   FROM readings_queue where length(_error) > 0;
"

sleep 5

echo 
#kafka-console-consumer --bootstrap-server localhost:9092 --from-beginning --topic readings-error

exit
# Reread messages from kafka 
#TRUNCATE TABLE readings;
#TRUNCATE TABLE readings_queue_error;
#DETACH TABLE readings_queue;
#Reset offset in kafka
#kafka-consumer-groups --bootstrap-server localhost:9092 --topic readings --group readings_consumer_group --reset-offsets --to-earliest --execute
#ATTACH TABLE readings_queue;







