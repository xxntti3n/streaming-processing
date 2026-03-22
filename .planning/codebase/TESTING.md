# Testing Patterns

**Analysis Date:** 2026-03-22

## Test Framework

### Integration Tests

**Runner:** Shell scripts with Bash
**Location:** `./v1/tests/integration/`
**Pattern:** Custom shell-based test framework

**Test Structure:**
```bash
#!/bin/bash
set -e

NAMESPACE=${STREAMING_NAMESPACE:-streaming}
FAILURES=0

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
```

**Run Commands:**
```bash
./v1/tests/integration/connectivity-test.sh          # Run connectivity tests
./v1/tests/e2e/run-e2e.sh                           # Run end-to-end tests
./v1/scripts/test-integration.sh                    # Run all integration tests
```

### End-to-End Tests

**Runner:** Shell scripts with YAML configuration
**Location:** `./v1/tests/e2e/`
**Configuration:** `cdc-to-iceberg-test.yaml`

**Pattern:**
```yaml
# cdc-to-iceberg-test.yaml
test_cases:
  - name: "MySQL to Iceberg CDC Flow"
    steps:
      - name: "Insert product data"
        sql: "INSERT INTO products (name, price) VALUES ('Test Product', 29.99)"
      - name: "Verify in Iceberg"
        command: "spark-sql --catalog iceberg -e 'SELECT * FROM products'"
```

## Test Organization

**Location:**
- Integration tests: `./v1/tests/integration/`
- E2E tests: `./v1/tests/e2e/`
- Test scripts: `./v1/scripts/`

**Naming Convention:**
- Descriptive names: `connectivity-test.sh`, `run-e2e.sh`
- Clear purpose in filename

**Directory Structure:**
```
tests/
├── integration/     # Component connectivity tests
├── e2e/           # End-to-end workflow tests
└── scripts/       # Test utilities and runners
```

## Test Structure

### Integration Test Pattern
```bash
#!/bin/bash
set -e

# Configuration
NAMESPACE=${STREAMING_NAMESPACE:-streaming}
FAILURES=0

# Test functions
test_connectivity() {
    local pod_name=$1
    local command=$2
    local expected=$3

    echo "Testing connectivity to $pod_name"
    kubectl exec -n "$NAMESPACE" "$pod_name" -- $command | grep -q "$expected"
    test_result "$pod_name connectivity" $?
}

# Main test execution
echo "=== Integration Connectivity Tests ==="

# Test Kafka connectivity
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
fi

# Report results
echo ""
echo "Results: $FAILURES failures"
[[ $FAILURES -eq 0 ]] && exit 0 || exit 1
```

### E2E Test Pattern
```bash
#!/bin/bash
set -e

echo "=== End-to-End CDC Test ==="

# Apply test data
kubectl apply -f test-data.yaml

# Wait for CDC processing
sleep 30

# Verify results
if kubectl get iceberg-table products | grep -q "1 rows"; then
    echo "✓ PASS: CDC data successfully written to Iceberg"
else
    echo "✗ FAIL: CDC data not found in Iceberg"
    exit 1
fi
```

## Test Data Management

**Sample Data:**
- PostgreSQL: Realistic customer/order data
```sql
INSERT INTO customers (name, email) VALUES
    ('Alice Johnson', 'alice@example.com'),
    ('Bob Smith', 'bob@example.com');
```

**Test Data Location:**
- SQL files in version directories
- YAML configurations for E2E tests

## Test Environments

### Kubernetes Testing
- Use `kubectl` for pod operations
- Test namespace: `streaming` (configurable)
- Resource limits and quotas respected

### Component Testing
- MySQL → Kafka connectivity
- Kafka → Spark CDC flow
- Spark → Iceberg sink
- End-to-end data validation

## Test Patterns

### Connectivity Testing
```bash
# Test pod availability
kubectl get pod -n "$NAMESPACE" -l app="$COMPONENT"

# Test port forwarding
kubectl port-forward svc/spanner-emulator 9010:9010

# Test service endpoints
curl -f http://localhost:8080/health
```

### Data Validation
```bash
# Verify data in downstream system
kubectl exec "$POD" -- \
    spark-sql --catalog iceberg -e "SELECT COUNT(*) FROM products"

# Check CDC offsets
kubectl exec "$KAFKA_POD" -- \
    kafka-consumer-groups --describe --group "$GROUP_ID"
```

## Error Testing

### Timeout Handling
```bash
# Wait for operation with timeout
for i in {1..30}; do
    if kubectl get pod "$POD" --field-selector=status.phase=Running; then
        break
    fi
    sleep 1
done
```

### Failure Scenarios
- Network partitions
- Pod restarts
- Resource exhaustion
- Schema changes

## Test Reporting

### Output Format:
```
=== Integration Connectivity Tests ===
✓ PASS: MySQL → Kafka CDC
✓ PASS: Kafka → Spark CDC
✓ PASS: Spark → Iceberg CDC

Results: 0 failures
```

### Exit Codes:
- `0`: All tests passed
- `1`: One or more tests failed

## Test Dependencies

### Prerequisites:
- Kubernetes cluster running
- All streaming components deployed
- kubectl configured
- Spark CLI available
-jq for JSON processing

### Setup Commands:
```bash
# Deploy streaming stack
./scripts/start.sh default

# Verify deployment
./scripts/verify-stack.sh

# Run tests
./scripts/test-integration.sh
```

## Coverage Areas

### Component Coverage:
- MySQL CDC capture
- Kafka message delivery
- Spark streaming processing
- Iceberg sink operations
- End-to-end data flow

### Scenario Coverage:
- Normal operation
- Component failures
- Data validation
- Performance constraints

---

*Testing analysis: 2026-03-22*
```