clickhouse client -h localhost --port 9001 -n -q "
CREATE TABLE hourly_data
(
    domain_name String,
    event_time DateTime,
    count_views UInt64
)
ENGINE = Null;


CREATE TABLE monthly_aggregated_data
(
    domain_name String,
    month Date,
    sumCountViews AggregateFunction(sum, UInt64)
)
ENGINE = AggregatingMergeTree
ORDER BY (domain_name, month);



CREATE MATERIALIZED VIEW monthly_aggregated_data_mv
TO monthly_aggregated_data
AS
SELECT
    toDate(toStartOfMonth(event_time)) AS month,
    domain_name,
    sumState(count_views) AS sumCountViews
FROM hourly_data
GROUP BY
    domain_name,
    month;


CREATE TABLE year_aggregated_data
(
    domain_name String,
    year UInt16,
    sumCountViews UInt64
)
ENGINE = SummingMergeTree()
ORDER BY (domain_name, year);


CREATE MATERIALIZED VIEW year_aggregated_data_mv
TO year_aggregated_data
AS
SELECT
    toYear(toStartOfYear(month)) AS year,
    domain_name,
    sumMerge(sumCountViews) as sumCountViews
FROM monthly_aggregated_data
GROUP BY
    domain_name,
    year;
"
clickhouse client -h localhost --port 9001 -m -q "
INSERT INTO hourly_data values ('clickhouse.com', '2019-01-01 10:00:00', 1), ('clickhouse.com', '2019-02-02 00:00:00', 2), ('clickhouse.com', '2019-02-01 00:00:00', 3), ('clickhouse.com', '2020-01-01 00:00:00', 6);
"


clickhouse client -h localhost --port 9001 -m -q "
SELECT
    month,
    domain_name,
    sumMerge(sumCountViews) as sumCountViews
FROM monthly_aggregated_data
GROUP BY
    domain_name,
    month;
"

