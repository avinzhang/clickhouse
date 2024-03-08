
create or replace table test
(
  time DateTime,
  number Int32,
  string String
)
Engine = MergeTree()
Primary Key time;

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
FROM numbers(1000000);
"
n=$(( n + 1 ))
sleep 3
done

date
n=0
while [ $n -le 1500 ]
do
 curl -u default:$CC_PROD_PASS -sS https://$CC_PROD_HOST:8443/ -d '
  Insert into test
  SELECT
    now(),
    floor(randNormal(1000, 5)),
    randomString(4)
  FROM numbers(2)
  SETTINGS async_insert=1, wait_for_async_insert = 0, async_insert_busy_timeout_ms=60000, async_insert_max_data_size=10100000;
 '
 n=$(( n + 1 ))
done
date

date
n=0
printf '%s\n' {1..1500} | xargs -P 10 -I {} curl -u jeremy:"Password@123456" -sS https://eduns8oore.ap-southeast-2.aws.clickhouse.cloud:8443/ -d '
Insert into test
SELECT
  now(),
  floor(randNormal(1000, 5)),
  randomString(4)
FROM numbers(2)
SETTINGS async_insert=1, wait_for_async_insert = 0, async_insert_busy_timeout_ms=60000, async_insert_max_data_size=10100000;
'
date
