#!/bin/bash


#To change the number of keepers or clickhouse nodes, use play.yml
echo "* Generate docker-compose and clickhouse configs"
docker-compose-templer -f play.yml


#XML configs for keepers and clickhouse nodes.  
#By default, 3 keepers, 1 shard, 2 replicas
#To change, see help: python3 create_config.py --help
python3 create_config.py 
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
