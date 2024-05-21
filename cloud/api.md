* Get service details
  ```
  curl -u $CC_ACCESS_KEY:$CC_SECRET_KEY https://api.clickhouse.cloud/v1/organizations/$CC_ORG_ID/services/$CC_SVC_ID
  ```

* Scale servcie memory
  ```
  curl --silent --user $CC_ACCESS_KEY:$CC_SECRET_KEY -X PATCH -H "Content-Type: application/json" https://api.clickhouse.cloud/v1/organizations/$CC_ORG_ID/services/$CC_SVC_ID/scaling -d '{ "maxTotalMemoryGb": 48 }'
  ```
