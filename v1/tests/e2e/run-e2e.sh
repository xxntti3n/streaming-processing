#!/bin/bash
set -e

NAMESPACE=${STREAMING_NAMESPACE:-streaming}

echo "=== Running E2E Tests ==="

# Apply test ConfigMap
kubectl apply -f tests/e2e/cdc-to-iceberg-test.yaml

echo "✓ E2E test framework deployed"
echo "Note: Full test requires running streaming stack"
