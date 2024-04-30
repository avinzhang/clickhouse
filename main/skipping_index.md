* Type (set)
  ```
  CREATE TABLE skip_table
    (
      my_key UInt64,
      my_value UInt64
    )
  ENGINE MergeTree primary key my_key
  SETTINGS index_granularity=8192;

  ALTER TABLE skip_table ADD INDEX vix my_value TYPE set(100) GRANULARITY 2;

  INSERT INTO skip_table SELECT number, intDiv(number,4096) FROM numbers(100000000);

  # explain shows skipping index is used, granules 4/12209 will be used fr the query
  EXPLAIN indexes = 1 SELECT * FROM skip_table WHERE my_value IN (125, 700);
  ```

* type (bloom filter - tokenbf_v1)
  ```
  CREATE TABLE MY_TABLE
  (
    `Year` LowCardinality(String),
    `Route` String,
    `Count` Float64,
    INDEX route_index (Route) TYPE tokenbf_v1(256, 2, 0) GRANULARITY 1
  )
  ENGINE = MergeTree
  ORDER BY tuple()
  SETTINGS index_granularity = 128;


  insert into MY_TABLE select '2020', arrayStringConcat(arrayMap(i-> toString(intHash32(i*number)) ,range(10)),','), number
from numbers(100000);
  insert into MY_TABLE select '2020', '2299008,2299008,2299008', number from numbers(100000000);
  OPTIMIZE TABLE MY_TABLE FINAL;

  --dropped granules
  explain indexes = 1 select Count(*) from MY_TABLE where hasToken(Route, '3119550599');

  --index doesn't drop any granules
  explain indexes = 1 select Count(*) from MY_TABLE where Route like '%3119550599%';

  ```
