#date
StartDate=`date +%s`
#seq 1 1500 | xargs -I $ -n1 -P10 curl -u default:"$CC_PROD_PASS" -sS "https://f5mjw0j8n6.ap-southeast-2.aws.clickhouse.cloud:8443" -d '
seq 1 10000000| xargs -I $ -n10 -P10 clickhouse client --host f5mjw0j8n6.ap-southeast-2.aws.clickhouse.cloud --secure --password $CC_PROD_PASS -mn -q "
set async_insert=1, async_insert_busy_timeout_ms=10000;
Insert into test
SELECT
  now(),
  floor(randNormal(1000, 5)),
  randomString(4)
FROM numbers(1);
"


FinalDate=`date +%s`
echo $((FinalDate-StartDate)) | awk '{print int($1/60)":"int($1%60)}'
#SETTINGS async_insert=1, wait_for_async_insert = 0, async_insert_busy_timeout_ms=10000, async_insert_max_data_size=1100000;

#set async_insert=1, async_insert_busy_timeout_ms=10000;
