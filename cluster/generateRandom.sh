#!/bin/bash

#docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
#create or replace table test
#(
#  time DateTime,
#  number Int32,
#  string String
#)
#Engine = MergeTree()
#Primary Key time;
#"

n=0
while [ $n -le 100 ]
do
docker exec -it clickhouse01 clickhouse-client -h localhost -nm -q "
set async_insert = 1;
Insert into test 
SELECT
    toDateTime('2023-12-12 12:00:00') - (((12 + randPoisson(12)) * 60) * 60 * 365 * 5),
    floor(randNormal(1000, 5)),
    randomString(4)
FROM numbers(10000);
"
n=$(( n + 1 ))
sleep 3
done

