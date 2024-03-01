create or replace table test
(
  time DateTime,
  number Int32,
  string String
)
Engine = MergeTree()
Primary Key time
TTL 
  time TO VOLUME 'default',
  time + INTERVAL 10 SECOND TO VOLUME 'warm_volume',
  time + INTERVAL 20 SECOND TO VOLUME 'cold_volume';


---
ALTER TABLE test
   MODIFY TTL
      time TO VOLUME 'default',
      time + INTERVAL 10 SECOND TO VOLUME 'warm_volume',
      time + INTERVAL 20 SECOND TO VOLUME 'cold_volume';
 
ALTER TABLE test
    MATERIALIZE TTL;
---


Insert into test
SELECT
  toUnixTimestamp(now()),
  floor(randNormal(1000, 5)),
  randomString(4)
FROM numbers(1);

SELECT
    name,
    disk_name
FROM system.parts
WHERE (table = 'test') AND (active = 1);
