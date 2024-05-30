CREATE TABLE s3_queue_table_engine
(
    `ParameterId` String,
    `ParameterName` String,
    `Currency` String,
    `ScaleId` String,
    `ViewId` String,
    `UnitId` String,
    `ParentParameterId` String,
    `DisplayParameterName` String,
    `SortOrder` String,
    `Sign` String,
    `StockflowId` String,
    `FlowtypeId` String,
    `SLIUniversalId` String,
    `GroupId` String,
    `CategoryId` String,
    `SLIId` String,
    `SecondaryUnit` String,
    `UnitOperator` String,
    `FuzzySLIId` String,
    `TagId` String,
    `AccountingBasisType` String
)
ENGINE = S3Queue('https://jeremy-ch.s3-ap-southeast-2.amazonaws.com/Meta*_OPSSTD_*.csv', 'CSV')
SETTINGS mode = 'ordered', s3queue_enable_logging_to_s3queue_log = 1, s3queue_processing_threads_num = 10, s3queue_current_shard_num = 0;

CREATE TABLE test_s3_queue_table
(
    `ParameterId` String,
    `ParameterName` String,
    `Currency` String,
    `ScaleId` String,
    `ViewId` String,
    `UnitId` String,
    `ParentParameterId` String,
    `DisplayParameterName` String,
    `SortOrder` String,
    `Sign` String,
    `StockflowId` String,
    `FlowtypeId` String,
    `SLIUniversalId` String,
    `GroupId` String,
    `CategoryId` String,
    `SLIId` String,
    `SecondaryUnit` String,
    `UnitOperator` String,
    `FuzzySLIId` String,
    `TagId` String,
    `AccountingBasisType` String
)
ENGINE = SharedMergeTree()
ORDER BY ParameterId;

CREATE MATERIALIZED VIEW s3_queue_view TO test_s3_queue_table
(
    `ParameterId` String,
    `ParameterName` String,
    `Currency` String,
    `ScaleId` String,
    `ViewId` String,
    `UnitId` String,
    `ParentParameterId` String,
    `DisplayParameterName` String,
    `SortOrder` String,
    `Sign` String,
    `StockflowId` String,
    `FlowtypeId` String,
    `SLIUniversalId` String,
    `GroupId` String,
    `CategoryId` String,
    `SLIId` String,
    `SecondaryUnit` String,
    `UnitOperator` String,
    `FuzzySLIId` String,
    `TagId` String,
    `AccountingBasisType` String
) AS
SELECT *
FROM default.s3_queue_table_engine;
