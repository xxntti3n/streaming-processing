#!/bin/bash
set -e

NAMESPACE=${STREAMING_NAMESPACE:-streaming}
FAILURES=0

echo "=== Integration Connectivity Tests ==="

test_result() {
  local test_name=$1
  local result=$2
  if [[ $result -eq 0 ]]; then
    echo "✓ PASS: $test_name"
  else
    echo "✗ FAIL: $test_name"
    ((FAILURES++))
  fi
}

# Test Kafka connectivity
echo "Test: MySQL → Kafka (Debezium)"
KAFKA_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=kafka -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -n "$KAFKA_POD" ]]; then
  kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- \
    kafka-console-consumer \
      --bootstrap-server localhost:9092 \
      --topic mysql-cdc.appdb.products \
      --from-beginning \
      --timeout-ms 5000 \
      --max-messages 1 >/dev/null 2>&1
  test_result "MySQL → Kafka CDC" $?
else
  echo "⚠ SKIP: Kafka pod not found"
fi

echo ""
echo "Results: $FAILURES failures"
[[ $FAILURES -eq 0 ]] && exit 0 || exit 1
