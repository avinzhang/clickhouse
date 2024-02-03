CREATE DATABASE dict_join;
USE dict_join;

CREATE TABLE table_for_dict (
  key_column UInt64,
  third_column String
)
ENGINE = MergeTree()
ORDER BY key_column;

INSERT INTO table_for_dict select number, concat('Hello World ', toString(number)) from numbers(10000000);

CREATE DICTIONARY ndict(
  key_column UInt64 DEFAULT 0,
  third_column String DEFAULT 'qqq'
)
PRIMARY KEY key_column
SOURCE(CLICKHOUSE(TABLE 'table_for_dict'))
LIFETIME(MIN 1 MAX 10)
LAYOUT(HASHED());



SELECT dictGet('ndict', 'third_column', toUInt64(1));


#join the table and dictionary
#* inefficent query
SELECT *
FROM numbers(100000) AS n
INNER JOIN ndict ON key_column = number;

# more effient query
SELECT
    number,
    dictGet('ndict', 'third_column', number)
FROM numbers(100000);


