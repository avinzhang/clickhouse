* Create destination table
  ```
   CREATE TABLE materialized_view.s3_dest
    (
        `update_time` UInt32,
        `id` Nullable(UInt32),
        `deleted` Nullable(UInt8),
        `type` Nullable(Int8),
        `by` Nullable(String),
        `time` Nullable(UInt32),
        `text` Nullable(String),
        `dead` Nullable(UInt8),
        `parent` Nullable(UInt32),
        `poll` Nullable(UInt32),
        `kids` Array(Nullable(UInt32)),
        `url` Nullable(String),
        `score` Nullable(Int32),
        `title` Nullable(String),
        `parts` Array(Nullable(UInt32)),
        `descendants` Nullable(Int32)
    )
    ENGINE = MergeTree()
    ORDER BY update_time;
  ```

* Create S3Queue table engine
  ```
   CREATE TABLE s3_engine
    (
        `update_time` UInt32,
        `id` Nullable(UInt32),
        `deleted` Nullable(UInt8),
        `type` Nullable(Int8),
        `by` Nullable(String),
        `time` Nullable(UInt32),
        `text` Nullable(String),
        `dead` Nullable(UInt8),
        `parent` Nullable(UInt32),
        `poll` Nullable(UInt32),
        `kids` Array(Nullable(UInt32)),
        `url` Nullable(String),
        `score` Nullable(Int32),
        `title` Nullable(String),
        `parts` Array(Nullable(UInt32)),
        `descendants` Nullable(Int32)
    )
    ENGINE = S3Queue('https://clickhouse-public-datasets.s3.amazonaws.com/hackernews_2024050*.parquet', 'Parquet')
  ```

* Create MV with S3Queue table engine
  ```
  CREATE MATERIALIZED VIEW s3_mv TO s3_dest
  AS SELECT * FROM materialized_view.s3_engine;
  ```

