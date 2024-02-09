#!/bin/bash


#XML configs for keepers and clickhouse nodes.
#By default, 3 keepers, 1 shard, 2 replicas
#To change, see help: python3 create_config.py --help
num_of_shards=1
num_of_replicas=2
python3 create_config.py -s $num_of_shards -r $num_of_replicas
num_of_nodes=$((num_of_shards * num_of_replicas))
init_node=clickhouse01
nodes=""
i=2
while [ $i -le 6 ]
  do
    nodes=`echo $init_node | sed -e "s/$/ clickhouse0$i/"`
    init_node=$nodes
    i=$(( $i + 1 ))
done
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
docker-compose up -d --build --no-deps $nodes
echo


