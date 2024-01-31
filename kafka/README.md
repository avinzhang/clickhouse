# Use case
Kafka Table Engine uses `kafka_handle_error_mode` to handle malformed messages, if it's set to `default`, the insertion from Kafka to Clickhouse will stop if there's a malformed message in the kafka topic; If it's set to `stream`, the insertion will continue even if there's any malformed message in the topic. The raw message and error will be routed to the `_raw_message` and `_error` virtual columns in the table created with kafka table engine. Below setup will describe how to route the raw messages and errors back to kafka for error rate calculation and message reprocessing in Kafka.

# Setup
1. Setup from Kafka to Clickhouse, using the following settings
   kafka_handle_error_mode = 'stream'
   Refer to https://clickhouse.com/docs/en/integrations/kafka/kafka-table-engine
   
2. Create a materialized view to route the good messages into Clickhouse table
   ```
   CREATE MATERIALIZED VIEW github_mv TO github AS
   SELECT *
   FROM github_queue where length(_error) == 0;
   ```

3. Create another materialized view to route the malformed messages into a topic "github-rejects" in Kafka
   ```
   CREATE OR REPLACE TABLE readings_out_queue (
    topic String,
    partition Int64,
    offset Int64,
    raw String,
    error String
   )
   ENGINE = Kafka
   SETTINGS kafka_broker_list = 'kafka:9092',
       kafka_topic_list = 'github-rejects',
       kafka_group_name = 'github_reject_consumer_group',
       kafka_format = 'JSON';



   CREATE MATERIALIZED VIEW github_out_queue_mv to github_out_queue
   AS
   SELECT _topic AS topic,
               _partition AS partition,
               _offset AS offset,
               _raw_message AS raw,
               _error AS error
   FROM github_queue where length(_error) > 0;
   ```

4. Use kafka console consumer to start consuming the github-rejects topic
   ```
   kafka-console-consumer --bootstrap-server kafka:9092 --from-beginning --topic github-rejects
   ```

5. Produce some messages containing malformed messages into the github topic in Kafka, notice the second message's file_time has been replaced with a string type, which is invalid DateTime type.
   ```
   kafka-console-producer --bootstrap-server <host>:<port> --topic readings <<END
   {"file_time":"2019-09-23 11:00:00","event_type":"PullRequestReviewCommentEvent","actor_login":"excitoon","repo_name":"ClickHouse\/ClickHouse","created_at":"2019-09-23 11:25:54","updated_at":"2019-09-23 11:25:54","action":"created","comment_id":"327062451","path":"dbms\/src\/TableFunctions\/TableFunctionS3.h","ref":"","ref_type":"none","creator_user_login":"excitoon","number":5596,"title":"s3 table function and storage","labels":["can be tested","pr-feature"],"state":"closed","assignee":"","assignees":[],"closed_at":"2019-09-22 21:53:07","merged_at":"2019-09-22 21:53:07","merge_commit_sha":"2054f80623f0454b1aabeccbaffc49e17e005926","requested_reviewers":["stavrolia"],"merged_by":"","review_comments":0,"member_login":""}
   {"file_time":"badmessage","event_type":"PullRequestReviewCommentEvent","actor_login":"excitoon","repo_name":"ClickHouse\/ClickHouse","created_at":"2019-09-23 11:27:59","updated_at":"2019-09-23 11:27:59","action":"created","comment_id":"327063172","path":"dbms\/src\/TableFunctions\/TableFunctionS3.h","ref":"","ref_type":"none","creator_user_login":"excitoon","number":5596,"title":"s3 table function and storage","labels":["can be tested","pr-feature"],"state":"closed","assignee":"","assignees":[],"closed_at":"2019-09-22 21:53:07","merged_at":"2019-09-22 21:53:07","merge_commit_sha":"2054f80623f0454b1aabeccbaffc49e17e005926","requested_reviewers":["stavrolia"],"merged_by":"","review_comments":0,"member_login":""}
   {"file_time":"2019-09-23 11:00:00","event_type":"PullRequestReviewCommentEvent","actor_login":"excitoon","repo_name":"ClickHouse\/ClickHouse","created_at":"2019-09-23 11:29:26","updated_at":"2019-09-23 11:29:27","action":"created","comment_id":"327063690","path":"dbms\/src\/Storages\/StorageS3.h","ref":"","ref_type":"none","creator_user_login":"excitoon","number":5596,"title":"s3 table function and storage","labels":["can be tested","pr-feature"],"state":"closed","assignee":"","assignees":[],"closed_at":"2019-09-22 21:53:07","merged_at":"2019-09-22 21:53:07","merge_commit_sha":"2054f80623f0454b1aabeccbaffc49e17e005926","requested_reviewers":["stavrolia"],"merged_by":"","review_comments":0,"member_login":""}
   END
   ```

6. The malformed message should be returned back to github-rejects topic, you should see it from the command output in step 4, which can be used on Kafka side for error rate calculation etc.
