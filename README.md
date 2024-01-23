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
* Use system.query_log to find out query details
  ```
  select 
    query,
    tables[1] as Table,
    ProfileEvents['SelectedMarks'] as SelectedMarks,
    formatReadableQuantity(ProfileEvents['SelectedRows']) as SelectedRows,
    query_duration_ms::String || ' ms' as query_duration
  from clusterAllReplicas(default, system.query_log)
  where type = 'QueryFinish' and query_kind = 'Select' and
    (tables = ['default.hits'] or tables = ['default.hits_noPrimaryKey'])
  order by inital_query_start_time DESC
  LIMIT 2;
  ```
