#!/bin/bash

echo
echo "* Download Kafka datagen connector and clickhouse sink connector"
mkdir confluent-hub-components
wget -O /tmp/confluentinc-kafka-connect-datagen-0.6.3.zip https://d1i4a15mxbxib1.cloudfront.net/api/plugins/confluentinc/kafka-connect-datagen/versions/0.6.3/confluentinc-kafka-connect-datagen-0.6.3.zip
wget -O /tmp/clickhouse-clickhouse-kafka-connect-v1.0.10.zip https://d1i4a15mxbxib1.cloudfront.net/api/plugins/clickhouse/clickhouse-kafka-connect/versions/v1.0.10/clickhouse-clickhouse-kafka-connect-v1.0.10.zip
unzip /tmp/confluentinc-kafka-connect-datagen-0.6.3.zip -d ./confluent-hub-components/
unzip /tmp/clickhouse-clickhouse-kafka-connect-v1.0.10.zip -d ./confluent-hub-components/
echo "Start the cluster"
docker-compose up -d
sleep 5
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

sleep 3
echo "* Check connector status"
echo "  datagen-users:  `curl -s http://localhost:8083/connectors/datagen-users/status | jq .connector.state`"
echo
echo 
echo "* Create table in Clickhouse"
docker exec -it clickhouse01 bash -c 'clickhouse-client -h localhost -q "CREATE DATABASE kafka ON CLUSTER 'cluster_1S_2R';"'
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
CREATE TABLE kafka.users on cluster 'cluster_1S_2R'
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
echo
echo
echo
echo "* Select data from kafka.users table"
docker exec -it clickhouse01 clickhouse-client -h localhost -q "
select * from kafka.users;
"