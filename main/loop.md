#create s3 table engine
CREATE TABLE LogsQueue (
  line String
)
ENGINE = S3Queue(
  'https://logs-mv.clickhouse.com.s3.amazonaws.com/*.log',
  NOSIGN,
  LineAsString
)
SETTINGS
  mode = 'ordered',
  s3queue_enable_logging_to_s3queue_log = 1;


CREATE TABLE logs (
  ip String,
  date DateTime,
  method LowCardinality(String),
  url String,
  statusCode UInt16,
  browser String
)
ENGINE = MergeTree
ORDER BY(url, date);


CREATE MATERIALIZED VIEW logsConsumer TO logs AS
WITH logs AS (
  FROM LogsQueue 
  SELECT parseLogLine(line) AS parts
)
FROM logs
SELECT parts[1][1] AS ip,
       parseDateTimeBestEffort(
         replaceRegexAll(parts[2][1], '/', ' ') || ' ' || parts[3][1]
       ) AS date,
       parts[4][1] AS method,
       parts[5][1] AS url,
       parts[6][1] AS statusCode,
       parts[-1][1] AS browser
WHERE length(parts[4]) > 0;


#check the logs table
SELECT *, sleep(3) AS _ FROM loop(view(
                          FROM logs SELECT count(), now() 
                    )) FORMAT PrettyCompact;
