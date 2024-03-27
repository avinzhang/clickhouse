#!/bin/bash


table_names=`clickhouse client --user default --password "$CC_PROD_PASS" --host $CC_PROD_HOST --secure -q "show tables from system;"`
echo $table_names

# Note system.zookeeper table is now allowed
for i in $table_names
do
  echo "Grant for $i"
  clickhouse client --user default --password "$CC_PROD_PASS" --host $CC_PROD_HOST --secure -q "GRANT SELECT ON system.$i TO testrole;"
done
