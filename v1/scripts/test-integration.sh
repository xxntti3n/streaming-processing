#!/bin/bash
# scripts/test-integration.sh
# Run integration tests for streaming stack

set -e

NAMESPACE=${STREAMING_NAMESPACE:-streaming}
FAILURES=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Integration Tests ==="
echo ""

test_kafka_connectivity() {
  echo -e "${YELLOW}Test: Kafka connectivity${NC}"

  KAFKA_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=kafka -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -z "$KAFKA_POD" ]]; then
    echo -e "${RED}  ✗ FAIL: Kafka pod not found${NC}"
    ((FAILURES++))
    return
  fi

  if kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- \
    kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ PASS${NC}"
  else
    echo -e "${RED}  ✗ FAIL: Cannot connect to Kafka${NC}"
    ((FAILURES++))
  fi
}

test_lakekeeper_catalog() {
  echo -e "${YELLOW}Test: Lakekeeper catalog${NC}"

  LAKEKEEPER_SVC=$(kubectl get svc -n "$NAMESPACE" lakekeeper -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)

  if [[ -z "$LAKEKEEPER_SVC" ]]; then
    echo -e "${RED}  ✗ FAIL: Lakekeeper service not found${NC}"
    ((FAILURES++))
    return
  fi

  HTTP_CODE=$(kubectl run -n "$NAMESPACE" lakekeeper-test --image=curlimages/curl:latest \
    --rm -i --restart=Never -- \
    curl -s -o /dev/null -w "%{http_code}" http://lakekeeper:8181/v1/config 2>/dev/null || echo "000")

  if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "401" ]]; then
    echo -e "${GREEN}  ✓ PASS${NC}"
  else
    echo -e "${RED}  ✗ FAIL: Lakekeeper returned HTTP $HTTP_CODE${NC}"
    ((FAILURES++))
  fi
}

test_minio_buckets() {
  echo -e "${YELLOW}Test: MinIO buckets${NC}"

  MINIO_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -z "$MINIO_POD" ]]; then
    echo -e "${RED}  ✗ FAIL: MinIO pod not found${NC}"
    ((FAILURES++))
    return
  fi

  BUCKETS=$(kubectl exec -n "$NAMESPACE" "$MINIO_POD" -- \
    mc alias set local http://localhost:9000 minio minio123 > /dev/null 2>&1 \
    && mc ls local/ 2>/dev/null | wc -l || echo "0")

  if [[ "$BUCKETS" -gt 0 ]]; then
    echo -e "${GREEN}  ✓ PASS ($BUCKETS buckets found)${NC}"
  else
    echo -e "${RED}  ✗ FAIL: No buckets found${NC}"
    ((FAILURES++))
  fi
}

test_mysql_connection() {
  echo -e "${YELLOW}Test: MySQL connection${NC}"

  MYSQL_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -z "$MYSQL_POD" ]]; then
    echo -e "${RED}  ✗ FAIL: MySQL pod not found${NC}"
    ((FAILURES++))
    return
  fi

  if kubectl exec -n "$NAMESPACE" "$MYSQL_POD" -- \
    mysqladmin ping -h localhost -u root -prootpw > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ PASS${NC}"
  else
    echo -e "${RED}  ✗ FAIL: Cannot connect to MySQL${NC}"
    ((FAILURES++))
  fi
}

# Run tests
test_kafka_connectivity
test_lakekeeper_catalog
test_minio_buckets
test_mysql_connection

echo ""
echo "=== Test Results ==="
if [[ $FAILURES -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi
