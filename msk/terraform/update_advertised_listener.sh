#!/bin/bash

brokers_domain_name=$1
bootstrap_port=9094
replication_port=9093
replication_secure_port=9095
for i in 1 2 3; do
        broker_server=b-$i.$brokers_domain_name
        bootstrap_server=$broker_server:$bootstrap_port
        internal_server=b-$i-internal.$brokers_domain_name
        listener_port=900$i

        client_secure=$broker_server:$listener_port
        replication=$internal_server:$replication_port
        replication_secure=$internal_server:$replication_secure_port

./bin/kafka-configs \
--bootstrap-server $bootstrap_server \
--entity-type brokers \
--entity-name $i \
--alter \
--command-config /root/client.properties \
--add-config advertised.listeners=[\
CLIENT_SECURE://$client_secure,\
REPLICATION://$replication,\
REPLICATION_SECURE://$replication_secure\
]

done
