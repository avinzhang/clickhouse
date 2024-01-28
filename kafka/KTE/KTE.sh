#!/bin/bash

docker-compose up -d --build --no-deps kafka keeper01 keeper02 keeper03

KEEPERS_STARTED=false
while [ "$KEEPERS_STARTED" = "false" ]
do
    echo "Waiting for Keepers to start..."
    keeper01_status=`docker-compose exec keeper01 bash -c "echo ruok |nc localhost 9181"`
    keeper02_status=`docker-compose exec keeper02 bash -c "echo ruok |nc localhost 9181"`
    keeper03_status=`docker-compose exec keeper03 bash -c "echo ruok |nc localhost 9181"`
    if [ "$keeper01_status" = "imok" ] && [ "$keeper02_status" = "imok" ] && [ "$keeper03_status" = "imok" ]; then
       echo "Keepers are started and ready" 
       KEEPERS_STARTED=true
    fi
    sleep 5
done

docker-compose up -d --build --no-deps clickhouse01 clickhouse02

KAFKA_STARTED=false
while [ $KAFKA_STARTED == false ]
do
    docker-compose logs kafka | grep "Kafka Server started" &> /dev/null
    if [ $? -eq 0 ]; then
      KAFKA_STARTED=true
      echo "kafka is started and ready"
    else
      echo "Waiting for Kafka to start..."
    fi
    sleep 5
done

echo "* Create github MergeTree table"
docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "
CREATE TABLE github
(
    file_time DateTime,
    event_type Enum('CommitCommentEvent' = 1, 'CreateEvent' = 2, 'DeleteEvent' = 3, 'ForkEvent' = 4, 'GollumEvent' = 5, 'IssueCommentEvent' = 6, 'IssuesEvent' = 7, 'MemberEvent' = 8, 'PublicEvent' = 9, 'PullRequestEvent' = 10, 'PullRequestReviewCommentEvent' = 11, 'PushEvent' = 12, 'ReleaseEvent' = 13, 'SponsorshipEvent' = 14, 'WatchEvent' = 15, 'GistEvent' = 16, 'FollowEvent' = 17, 'DownloadEvent' = 18, 'PullRequestReviewEvent' = 19, 'ForkApplyEvent' = 20, 'Event' = 21, 'TeamAddEvent' = 22),
    actor_login LowCardinality(String),
    repo_name LowCardinality(String),
    created_at DateTime,
    updated_at DateTime,
    action Enum('none' = 0, 'created' = 1, 'added' = 2, 'edited' = 3, 'deleted' = 4, 'opened' = 5, 'closed' = 6, 'reopened' = 7, 'assigned' = 8, 'unassigned' = 9, 'labeled' = 10, 'unlabeled' = 11, 'review_requested' = 12, 'review_request_removed' = 13, 'synchronize' = 14, 'started' = 15, 'published' = 16, 'update' = 17, 'create' = 18, 'fork' = 19, 'merged' = 20),
    comment_id UInt64,
    path String,
    ref LowCardinality(String),
    ref_type Enum('none' = 0, 'branch' = 1, 'tag' = 2, 'repository' = 3, 'unknown' = 4),
    creator_user_login LowCardinality(String),
    number UInt32,
    title String,
    labels Array(LowCardinality(String)),
    state Enum('none' = 0, 'open' = 1, 'closed' = 2),
    assignee LowCardinality(String),
    assignees Array(LowCardinality(String)),
    closed_at DateTime,
    merged_at DateTime,
    merge_commit_sha String,
    requested_reviewers Array(LowCardinality(String)),
    merged_by LowCardinality(String),
    review_comments UInt32,
    member_login LowCardinality(String)
) ENGINE = MergeTree ORDER BY (event_type, repo_name, created_at);
"


# Create kafka topic
echo "* Create kafka topic"
kafka-topics --bootstrap-server localhost:9092 --topic github --create --replication-factor 1 

# Produce messages to the topic
echo "* Produce messages to kafka topic using github.ndjson file"
kafka-console-producer --bootstrap-server localhost:9092 --topic github < ./github.ndjson

sleep 3

echo " Check message are produced into the topic correctly"
kafka-console-consumer --bootstrap-server localhost:9092 --topic github --from-beginning --timeout-ms 1000

#create kafka table engine
docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "
CREATE TABLE github_queue
(
    file_time DateTime,
    event_type Enum('CommitCommentEvent' = 1, 'CreateEvent' = 2, 'DeleteEvent' = 3, 'ForkEvent' = 4, 'GollumEvent' = 5, 'IssueCommentEvent' = 6, 'IssuesEvent' = 7, 'MemberEvent' = 8, 'PublicEvent' = 9, 'PullRequestEvent' = 10, 'PullRequestReviewCommentEvent' = 11, 'PushEvent' = 12, 'ReleaseEvent' = 13, 'SponsorshipEvent' = 14, 'WatchEvent' = 15, 'GistEvent' = 16, 'FollowEvent' = 17, 'DownloadEvent' = 18, 'PullRequestReviewEvent' = 19, 'ForkApplyEvent' = 20, 'Event' = 21, 'TeamAddEvent' = 22),
    actor_login LowCardinality(String),
    repo_name LowCardinality(String),
    created_at DateTime,
    updated_at DateTime,
    action Enum('none' = 0, 'created' = 1, 'added' = 2, 'edited' = 3, 'deleted' = 4, 'opened' = 5, 'closed' = 6, 'reopened' = 7, 'assigned' = 8, 'unassigned' = 9, 'labeled' = 10, 'unlabeled' = 11, 'review_requested' = 12, 'review_request_removed' = 13, 'synchronize' = 14, 'started' = 15, 'published' = 16, 'update' = 17, 'create' = 18, 'fork' = 19, 'merged' = 20),
    comment_id UInt64,
    path String,
    ref LowCardinality(String),
    ref_type Enum('none' = 0, 'branch' = 1, 'tag' = 2, 'repository' = 3, 'unknown' = 4),
    creator_user_login LowCardinality(String),
    number UInt32,
    title String,
    labels Array(LowCardinality(String)),
    state Enum('none' = 0, 'open' = 1, 'closed' = 2),
    assignee LowCardinality(String),
    assignees Array(LowCardinality(String)),
    closed_at DateTime,
    merged_at DateTime,
    merge_commit_sha String,
    requested_reviewers Array(LowCardinality(String)),
    merged_by LowCardinality(String),
    review_comments UInt32,
    member_login LowCardinality(String)
)
   ENGINE = Kafka('kafka:29092', 'github', 'clickhouse',
            'JSONEachRow') settings kafka_handle_error_mode = 'default', kafka_skip_broken_messages = 0, kafka_commit_on_select = 1, kafka_thread_per_consumer = 0, kafka_num_consumers = 1;
"
#kafka_handle_error_mode = 'stream',

#create materialized view to store messages
echo "* Create materialized view"
docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "
CREATE MATERIALIZED VIEW github_mv TO github AS
SELECT *
FROM github_queue;
"

sleep 10 
echo
echo "count the messages from github table"
docker exec -it clickhouse01 clickhouse-client -h localhost -mn -q "
select count() from github;
"
