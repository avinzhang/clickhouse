#!/bin/bash

num_of_shards=1
num_of_replicas=2
dc_template=docker-compose-kafka.yml
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
echo
echo "* Download Kafka datagen connector and clickhouse sink connector"
mkdir confluent-hub-components
ls /tmp/confluentinc-kafka-connect-datagen-0.6.3.zip || wget -O /tmp/confluentinc-kafka-connect-datagen-0.6.3.zip https://d1i4a15mxbxib1.cloudfront.net/api/plugins/confluentinc/kafka-connect-datagen/versions/0.6.3/confluentinc-kafka-connect-datagen-0.6.3.zip
ls /tmp/clickhouse-clickhouse-kafka-connect-v1.0.10.zip || wget -O /tmp/clickhouse-clickhouse-kafka-connect-v1.0.10.zip https://d1i4a15mxbxib1.cloudfront.net/api/plugins/clickhouse/clickhouse-kafka-connect/versions/v1.0.10/clickhouse-clickhouse-kafka-connect-v1.0.10.zip
unzip -n /tmp/confluentinc-kafka-connect-datagen-0.6.3.zip -d ./confluent-hub-components/
unzip -n /tmp/clickhouse-clickhouse-kafka-connect-v1.0.10.zip -d ./confluent-hub-components/

echo
echo "* Start kafka cluster"
docker-compose up -d --build --no-deps kafka connect schemaregistry
echo
echo "* Starting up clickhouse keepers"
docker-compose up -d --build --no-deps keeper01 keeper02 keeper03

KEEPERS_STARTED=false
while [ "$KEEPERS_STARTED" = "false" ]
do
    echo "   Waiting for Keepers to start..."
    keeper01_status=`echo ruok |nc localhost 9181`
    keeper02_status=`echo ruok |nc localhost 9182`
    keeper03_status=`echo ruok |nc localhost 9183`
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
curl -X POST -H "Content-Type: application/json" http://localhost:8083/connectors/ --data '{"name": "datagen-users", "config": {"connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector", "quickstart": "users", "name": "datagen-users", "kafka.topic": "datagen_users", "max.interval": "1000", "key.converter": "org.apache.kafka.connect.storage.StringConverter", "value.converter": "io.confluent.connect.avro.AvroConverter", "tasks.max": "1", "iterations": "1000000000",  "key.converter.schema.registry.url": "http://schemaregistry:8081", "value.converter.schema.registry.url": "http://schemaregistry:8081" }}'
curl -X POST -H "Content-Type: application/json" http://localhost:8083/connectors/ --data '{"name": "datagen-pageviews", "config": {"connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector", "quickstart": "pageviews", "name": "datagen-pageviews", "kafka.topic": "datagen_pageviews", "max.interval": "1000", "key.converter": "org.apache.kafka.connect.storage.StringConverter", "value.converter": "io.confluent.connect.avro.AvroConverter", "tasks.max": "1", "iterations": "1000000000",  "key.converter.schema.registry.url": "http://schemaregistry:8081", "value.converter.schema.registry.url": "http://schemaregistry:8081" }}'

sleep 3
echo "* Check connector datagen-users status"
echo "  datagen-users:  `curl -s http://localhost:8083/connectors/datagen-users/status | jq .connector.state`"
echo "* Check connector datagen-pageviews status"
echo "  datagen-users:  `curl -s http://localhost:8083/connectors/datagen-pageviews/status | jq .connector.state`"
echo
echo 
echo "* Create table in Clickhouse"
docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "
CREATE TABLE datagen_users 
(
    userid String,
    registertime Int64,
    gender String,
    regionid String
)
ENGINE = MergeTree
ORDER BY (userid);

CREATE TABLE datagen_pageviews (viewtime Int64, userid String, pageid String) ENGINE = MergeTree ORDER BY (viewtime);
"
echo
echo "* Create Clickhouse connector": 
curl -i -X POST \
    -H "Accept:application/json" \
    -H  "Content-Type:application/json" \
   http://localhost:8083/connectors/ -d '
  {
      "name": "clickhouse-datagen",
      "config": {
           "name": "clickhouse-datagen",
           "connector.class": "com.clickhouse.kafka.connect.ClickHouseSinkConnector",
           "database": "default",
           "zkDatabase": "keeperdb",
           "topics.regex": "datagen_.*",
           "table.name.format": "${topic}",
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
echo "* Check clickhouse connector status"
echo "  Clickhouse:  `curl -s http://localhost:8083/connectors/clickhouse-datagen/status | jq .connector.state`"
echo
echo
echo
echo "* Select data from users table"
docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "
select count() from default.datagen_users;
select count() from default.datagen_pageviews;
"
