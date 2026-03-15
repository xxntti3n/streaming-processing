#!/bin/bash
# verify-cdc-pipeline.sh - Verify CDC pipeline is working correctly
set -e

NAMESPACE="${NAMESPACE:-default}"

echo "=================================================="
echo "Verifying Spanner CDC Pipeline"
echo "=================================================="

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

PASS=0
FAIL=0

# Function to check a service
check_service() {
    local name=$1
    local namespace=$2
    if kubectl get svc "$name" -n "$namespace" &> /dev/null; then
        echo "✓ Service '$name' exists"
        ((PASS++))
        return 0
    else
        echo "✗ Service '$name' not found"
        ((FAIL++))
        return 1
    fi
}

# Function to check a pod is running
check_pod_running() {
    local label=$1
    local namespace=$2
    local status=$(kubectl get pods -l "$label" -n "$namespace" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
    if [ "$status" = "Running" ]; then
        echo "✓ Pod with label '$label' is running"
        ((PASS++))
        return 0
    else
        echo "✗ Pod with label '$label' not running (status: $status)"
        ((FAIL++))
        return 1
    fi
}

echo ""
echo "Checking Infrastructure..."
echo "--------------------------"

check_service "spanner-emulator" "$NAMESPACE"
check_service "flink-jobmanager" "$NAMESPACE"
check_service "flink-taskmanager" "$NAMESPACE"
check_service "bigquery-emulator" "$NAMESPACE"

echo ""
echo "Checking Pods..."
echo "--------------------------"

check_pod_running "app=spanner-emulator" "$NAMESPACE"
check_pod_running "app=flink,component=jobmanager" "$NAMESPACE"
check_pod_running "app=flink,component=taskmanager" "$NAMESPACE"
check_pod_running "app=bigquery-emulator" "$NAMESPACE"

echo ""
echo "Checking Flink Jobs..."
echo "--------------------------"

# Port forward to Flink UI
kubectl port-forward svc/flink-jobmanager 8081:8081 -n "$NAMESPACE" >/dev/null 2>&1 &
PF_PID=$!
sleep 2

# Check if Flink is responding
if curl -s http://localhost:8081 >/dev/null 2>&1; then
    echo "✓ Flink Web UI is accessible"
    ((PASS++))
else
    echo "✗ Flink Web UI is not accessible"
    ((FAIL++))
fi

kill $PF_PID 2>/dev/null || true

# Check for running jobs
JOBS=$(kubectl exec deployment/flink-jobmanager -n "$NAMESPACE" -- /opt/flink/bin/flink list -r 2>/dev/null | grep -c "spanner-cdc" || echo "0")
if [ "$JOBS" -gt 0 ]; then
    echo "✓ CDC job is running"
    ((PASS++))
else
    echo "✗ CDC job is not running"
    ((FAIL++))
fi

echo ""
echo "=================================================="
echo "Verification Complete"
echo "=================================================="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "✓ All checks passed!"
    exit 0
else
    echo "✗ Some checks failed"
    exit 1
fi
