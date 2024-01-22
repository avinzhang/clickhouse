* Generate sh256sum password
  ```
  echo -n "Hellopass" | sha256sum | tr -d '-'
  ```

* Find hardware specs for each replica in a service
  ```
  SELECT *
  FROM clusterAllReplicas('default', view(
      SELECT
          hostname() AS server,
          getSetting('max_threads') AS cpu_cores,
          formatReadableSize(getSetting('max_memory_usage')) AS memory
      FROM system.one
  ))
  ORDER BY server ASC
  SETTINGS skip_unavailable_shards = 1
  ```

* Find service 
  ```
  curl -s -u $CC_ACCESS_KEY:$CC_SECRET_KEY https://api.clickhouse.cloud/v1/organizations/orgId/services | jq -r '.result[]|select(.name == "avin")'
  ```
