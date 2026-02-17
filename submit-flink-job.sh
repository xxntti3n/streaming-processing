#!/bin/bash
# Submit the CDC join+aggregate streaming job to Flink (run after stack is up).

set -e
MAX_ATTEMPTS=60
echo "Waiting for Flink JobManager..."
for i in $(seq 1 $MAX_ATTEMPTS); do
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 2>/dev/null | grep -q "200\|302"; then
    echo "Flink is ready."
    break
  fi
  if [ "$i" -eq $MAX_ATTEMPTS ]; then
    echo "Flink did not become ready in time."
    exit 1
  fi
  sleep 2
done

echo "Submitting streaming job: MySQL CDC → join + aggregate → Iceberg (sales_by_product)"
docker exec -i streaming-jobmanager /opt/flink/bin/sql-client.sh -f /opt/flink/job.sql

echo "Done. Check jobs at http://localhost:8081 and query: docker exec streaming-trino trino --execute \"SELECT * FROM iceberg.demo.sales_by_product\""
