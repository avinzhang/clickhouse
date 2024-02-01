#!/bin/bash

echo "* Generate configs for clickhouse nodes"
#for keepers
node=1
while [ $node -le 3 ]
do
  mkdir -p ./config/keeper0${node}
  node=$node envsubst < ./config/keeper.xml > ./config/keeper0${node}/keeper.xml
  node=$((node+1))
done
shard_id=1
replica_id=1
node=1
while [ "$node" -le 2 ]
do
  while [ "$shard_id" -le 1 ]
  do
    while [ "$replica_id" -le 2 ]
    do
       mkdir -p ./config/clickhouse0${node}/
       node=$node replica_id=$replica_id shard_id=$shard_id envsubst < ./config/config.xml > ./config/clickhouse0${node}/config.xml
       node=$((node+1))
       replica_id=$((replica_id+1))
    done
    shard_id=$((shard_id+1))
    replica_id=1
  done
done

echo
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
docker-compose up -d --build --no-deps clickhouse01 clickhouse02
