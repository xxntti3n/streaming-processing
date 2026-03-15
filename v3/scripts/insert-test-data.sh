#!/bin/bash
# insert-test-data.sh - Insert test data into Spanner for CDC testing
set -e

INSTANCE_ID="test-instance"
DATABASE_ID="ecommerce"
PROJECT_ID="test-project"
NAMESPACE="${NAMESPACE:-default}"

echo "=================================================="
echo "Inserting Test Data into Spanner"
echo "=================================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Warning: kubectl not found. Cannot connect to Spanner emulator."
    exit 1
fi

# Port forward to Spanner emulator
kubectl port-forward svc/spanner-emulator 9010:9010 -n "$NAMESPACE" &
PF_PID=$!
sleep 3

cleanup() {
    kill $PF_PID 2>/dev/null || true
}
trap cleanup EXIT

export SPANNER_EMULATOR_HOST=localhost:9010

echo ""
echo "Inserting test customers..."
echo ""

# Insert test customers
for i in {1..5}; do
    echo "Inserting customer $i..."
    # Using spanner-cli or direct gcloud command would go here
    # For now, this is a placeholder showing what data would be inserted
    echo "  Customer ID: $i"
    echo "  Email: customer$i@example.com"
    echo "  Name: Customer $i"
done

echo ""
echo "Inserting test products..."
echo ""

for i in {1..5}; do
    echo "Inserting product $i..."
    echo "  Product ID: $i"
    echo "  SKU: PROD-00$i"
    echo "  Name: Product $i"
    echo "  Price: $((i * 10)).00"
done

echo ""
echo "Inserting test orders..."
echo ""

for i in {1..3}; do
    echo "Inserting order $i..."
    echo "  Order ID: $i"
    echo "  Customer ID: $i"
    echo "  Product ID: $i"
    echo "  Quantity: $((i * 2))"
    echo "  Status: PENDING"
done

echo ""
echo "=================================================="
echo "Test Data Insertion Complete!"
echo "=================================================="
echo ""
echo "Note: This script shows what data would be inserted."
echo "To actually insert data, use gcloud spanner rows insert or spanner-cli"
