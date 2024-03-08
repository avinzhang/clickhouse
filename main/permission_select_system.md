#!/bin/bash


echo "Create readonly role and user"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
CREATE ROLE readonly_role;
CREATE OR REPlACE USER IF NOT EXISTS readonly_user
IDENTIFIED WITH sha256_password
BY 'ClickHouse123';
"

echo "Grant select permission to readonly role on system tables"
for i in `docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "select name from system.tables where database = 'system';"`
do
  docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "GRANT SELECT ON system.$i TO readonly_role WITH GRANT OPTION;"
done

echo "Grant readonly role to readonly user"
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
GRANT readonly_role TO readonly_user;
"


for i in `clickhouse client --host f5mjw0j8n6.ap-southeast-2.aws.clickhouse.cloud -mn --secure --password $CC_PROD_PASS -q "select name from system.tables where database = 'system'"`
do
  echo "Granting table $i"
  clickhouse client --host f5mjw0j8n6.ap-southeast-2.aws.clickhouse.cloud -mn --secure --password $CC_PROD_PASS -q "GRANT SELECT ON system.$i TO readonly_role WITH GRANT OPTION;"
done
