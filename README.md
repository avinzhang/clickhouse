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

* Use "EXPAIN" 
  ** EXPLAIN indexes = 1
  ** EXPLAIN AST 
  ** EXPLAIN AST graph = 1
  ** EXPLAIN SYNTAX
  ** EXPLAIN PLAN indexes = 1, actions = 1
  ** EXPLAIN PIPELINE

* Checking max threads 
  ```
  select value from system.settings where name = 'max_threads';
  ```

* Check memory used for a query
  ```
  Select 
    query,
    query_duration_ms::String || ' ms' as query_duration
    formatReadableSize(memory_usage) as memory_usage,
  FROM clusterAllReplicas(default, system.query_log)
  WHERE type = 'QueryFinish' AND
    hasAny(tables, ['default.hits']) = 1
  ORDER by inital_query_start_time DESC
  LIMIT 3;
  ```
* Analyse slow query
  ```
  select 
    query_id, 
    normalized_query_hash, 
    type, 
    read_rows, 
    ProfileEvents['OSCPUWaitMicroseconds'], 
    formatReadableSize(ProfileEvents['CachedReadBufferReadFromCacheBytes']) AS read_from_cache,
    formatReadableSize(ProfileEvents['CachedReadBufferReadFromSourceBytes']) AS read_from_storage, 
    read_bytes, 
    query_duration_ms, 
    result_rows, 
    event_time_microseconds 
  from clusterAllReplicas(default, system.query_log) 
  where normalized_query_hash = '15292739615144886244' and type = 'QueryFinish' order by event_time_microseconds;
  ```
* Count the number of parts for each partition
  ```
  SELECT
    database,
    table,
    partition,
    sum(rows) AS rows,
    count() AS part_count
  FROM system.parts
  WHERE (active = 1) AND (table LIKE 'trips') AND (database LIKE 'default')
  GROUP BY
      database,
      table,
      partition
  ORDER BY part_count DESC;
  ```
* See list of new parts created in the last 2 hours
  ```
  SELECT
    count() AS new_parts,
    toStartOfMinute(event_time) AS modification_time_m,
    table,
    sum(rows) AS total_written_rows,
    formatReadableSize(sum(size_in_bytes)) AS total_bytes_on_disk
FROM clusterAllReplicas(default, system.part_log)
WHERE (event_type = 'NewPart') AND (event_time > (now() - toIntervalHour(2)))
GROUP BY
    modification_time_m,
    table
ORDER BY
    modification_time_m ASC,
    table DESC
    ```
