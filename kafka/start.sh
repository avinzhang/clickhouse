#!/bin/bash

echo "* Generate configs for clickhouse nodes"
#for keepers
node=1
while [ $node -le 1 ]
do
  mkdir -p ./config/clickhouse0${node}
  node=$node envsubst < ./config/keeper.xml > ./config/clickhouse0${node}/keeper.xml
  node=$((node+1))
done
shard_id=1
replica_id=1
node=1
while [ $shard_id -le 1 ]
do
  while [ $replica_id -le 1 ]
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
echo "* Download Kafka datagen connector and clickhouse sink connector"
mkdir confluent-hub-components
wget -O ./confluent-hub-components/confluentinc-kafka-connect-datagen-0.6.3.zip https://d1i4a15mxbxib1.cloudfront.net/api/plugins/confluentinc/kafka-connect-datagen/versions/0.6.3/confluentinc-kafka-connect-datagen-0.6.3.zip
wget -O ./confluent-hub-components/clickhouse-clickhouse-kafka-connect-v1.0.10.zip https://d1i4a15mxbxib1.cloudfront.net/api/plugins/clickhouse/clickhouse-kafka-connect/versions/v1.0.10/clickhouse-clickhouse-kafka-connect-v1.0.10.zip
unzip ./confluent-hub-components/confluentinc-kafka-connect-datagen-0.6.3.zip -d /tmp/
unzip ./confluent-hub-components/clickhouse-clickhouse-kafka-connect-v1.0.10.zip -d /tmp/
echo "Start the cluster"
docker-compose up -d
sleep 5
echo
echo "* Check clickhouse system.zookeeper table"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from system.zookeeper 
where path IN ('/', '/clickhouse')
"

echo
connect_ready=false
while [ $connect_ready == false ]
do
    docker compose logs connect|grep "Herder started" &> /dev/null
    if [ $? -eq 0 ]; then
      connect_ready=true
      echo "*** Kafka Connect is ready ****"
    else
      echo ">>> Waiting for kafka connect to start"
    fi
    sleep 5
done
echo
echo
echo "* Create datagen-user connector"
curl -X POST -H "Content-Type: application/json" http://localhost:8083/connectors/ --data '{"name": "datagen-users", "config": {"connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector", "quickstart": "users", "name": "datagen-users", "kafka.topic": "users", "max.interval": "1000", "key.converter": "org.apache.kafka.connect.storage.StringConverter", "value.converter": "io.confluent.connect.avro.AvroConverter", "tasks.max": "1", "iterations": "1000000000",  "key.converter.schema.registry.url": "http://schemaregistry:8081", "value.converter.schema.registry.url": "http://schemaregistry:8081" }}'

echo "* Create datagen-pageviews connector"
curl -X POST -H "Content-Type: application/json" http://localhost:8083/connectors/ --data '{"name": "datagen-pageviews", "config": {"connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector", "quickstart": "pageviews", "name": "datagen-pageviews", "kafka.topic": "pageviews", "max.interval": "1000", "key.converter": "org.apache.kafka.connect.storage.StringConverter", "value.converter": "io.confluent.connect.avro.AvroConverter", "tasks.max": "1", "iterations": "1000000000",  "key.converter.schema.registry.url": "http://schemaregistry:8081", "value.converter.schema.registry.url": "http://schemaregistry:8081" }}'
echo
sleep 3
echo "* Check connector status"
echo "  datagen-users:  `curl -s http://localhost:8083/connectors/datagen-users/status | jq .connector.state`"
echo "  datagen-pageviews:  `curl -s http://localhost:8083/connectors/datagen-pageviews/status | jq .connector.state`"
echo
echo 
echo "* Create table in Clickhouse"
docker exec -it clickhouse01 bash -c 'clickhouse-client -h localhost -q "CREATE DATABASE kafka ON CLUSTER 'cluster_1S_1R';"'
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE TABLE kafka.users on cluster 'cluster_1S_1R'
(
    userid String,
    registertime Int64,
    gender String,
    regionid String
)
ENGINE = MergeTree
ORDER BY (userid);
"
echo
echo "* Create Clickhouse connector": 
curl -i -X POST \
    -H "Accept:application/json" \
    -H  "Content-Type:application/json" \
   http://localhost:8083/connectors/ -d '
  {
      "name": "clickhouse-users",
      "config": {
           "name": "clickhouse-users",
           "connector.class": "com.clickhouse.kafka.connect.ClickHouseSinkConnector",
           "database": "kafka",
           "topics": "users",
           "hostname": "clickhouse01",
           "port": "8123",
           "request.method": "POST",
           "retry.on.status.codes": "400-500",
           "auth.type": "BASIC",
           "username": "default",
           "request.body.format": "JSON",
           "batch.max.size": "1000",
           "key.converter": "org.apache.kafka.connect.storage.StringConverter",
           "value.converter": "io.confluent.connect.avro.AvroConverter",
           "value.converter.schema.registry.url": "http://schemaregistry:8081",
           "tasks.max": "1"
       }
   }'

echo
sleep 3
echo "* Select data from kafka.users table"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from kafka.users;
"
