import requests
import time


CLICKHOUSE_CLOUD_URL = ''

start_time = time.time()
response = requests.get(CLICKHOUSE_CLOUD_URL)
end_time = time.time()

time_diff = round((end_time - start_time) * 1000)
print("Total time taken for the initial connection: %s milliseconds" % time_diff)
