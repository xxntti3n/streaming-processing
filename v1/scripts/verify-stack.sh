#!/bin/bash
# scripts/verify-stack.sh
# Verify health of deployed streaming stack

set -e

NAMESPACE=${STREAMING_NAMESPACE:-streaming}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Streaming Stack Health Check ==="
echo ""

check_pods() {
  echo -e "${YELLOW}Checking Pods...${NC}"
  PODS=$(kubectl get pods -n "$NAMESPACE" -o json)

  TOTAL=$(echo "$PODS" | jq '.items | length')
  READY=$(echo "$PODS" | jq '[.items[] | select(.status.phase=="Running")] | length')

  echo "  Pods: $READY/$TOTAL ready"

  # Check for non-running pods
  FAILED=$(echo "$PODS" | jq '[.items[] | select(.status.phase!="Running")] |
    [.[] | {name: .metadata.name, phase: .status.phase}]')

  if [[ "$FAILED" != "[]" ]]; then
    echo -e "${RED}  Non-running pods:${NC}"
    echo "$FAILED" | jq -r '.[] | "    - \(.name): \(.phase)"'
  else
    echo -e "${GREEN}  ✓ All pods running${NC}"
  fi
  echo ""
}

check_kafka() {
  echo -e "${YELLOW}Checking Kafka...${NC}"
  # Try to list topics via kafka-cli
  KAFKA_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=kafka -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$KAFKA_POD" ]]; then
    kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- \
      kafka-topics.sh --bootstrap-server localhost:9092 --list > /dev/null 2>&1 \
      && echo -e "${GREEN}  ✓ Kafka accessible${NC}" \
      || echo -e "${RED}  ✗ Kafka not accessible${NC}"
  else
    echo -e "${YELLOW}  ⚠ Kafka pod not found${NC}"
  fi
  echo ""
}

check_lakekeeper() {
  echo -e "${YELLOW}Checking Lakekeeper...${NC}"
  LAKEKEEPER_SVC=$(kubectl get svc -n "$NAMESPACE" lakekeeper -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)

  if [[ -n "$LAKEKEEPER_SVC" ]]; then
    # Try to access health endpoint
    kubectl run -n "$NAMESPACE" lakekeeper-check --image=curlimages/curl:latest \
      --rm -i --restart=Never -- \
      curl -f -s http://lakekeeper:8181/health > /dev/null 2>&1 \
      && echo -e "${GREEN}  ✓ Lakekeeper healthy${NC}" \
      || echo -e "${RED}  ✗ Lakekeeper not healthy${NC}"
  else
    echo -e "${YELLOW}  ⚠ Lakekeeper service not found${NC}"
  fi
  echo ""
}

check_minio() {
  echo -e "${YELLOW}Checking MinIO...${NC}"
  MINIO_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$MINIO_POD" ]]; then
    kubectl exec -n "$NAMESPACE" "$MINIO_POD" -- \
      mc alias set local http://localhost:9000 minio minio123 > /dev/null 2>&1 \
      && echo -e "${GREEN}  ✓ MinIO accessible${NC}" \
      || echo -e "${RED}  ✗ MinIO not accessible${NC}"
  else
    echo -e "${YELLOW}  ⚠ MinIO pod not found${NC}"
  fi
  echo ""
}

check_spark() {
  echo -e "${YELLOW}Checking Spark...${NC}"
  SPARK_PODS=$(kubectl get pod -n "$NAMESPACE" -l spark-role=driver -o jsonpath='{.items}' 2>/dev/null | jq 'length')

  if [[ "$SPARK_PODS" -gt 0 ]]; then
    echo -e "${GREEN}  ✓ Spark driver running${NC}"
  else
    echo -e "${YELLOW}  ⚠ No Spark driver pods found${NC}"
  fi
  echo ""
}

# Run checks
check_pods
check_kafka
check_lakekeeper
check_minio
check_spark

echo -e "${GREEN}=== Health Check Complete ===${NC}"
