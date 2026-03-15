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

# Insert test customers using gcloud spanner rows insert
for i in {1..5}; do
    echo "Inserting customer $i..."
    gcloud spanner rows insert \
        --instance="$INSTANCE_ID" \
        --database="$DATABASE_ID" \
        --table="customers" \
        --data=customer_id="$i",email="customer$i@example.com",name="Customer $i" \
        --project="$PROJECT_ID" 2>/dev/null && echo "  Successfully inserted customer $i" || echo "  Warning: Failed to insert customer $i (may already exist)"
done

echo ""
echo "Inserting test products..."
echo ""

# Insert test products
for i in {1..5}; do
    echo "Inserting product $i..."
    gcloud spanner rows insert \
        --instance="$INSTANCE_ID" \
        --database="$DATABASE_ID" \
        --table="products" \
        --data=product_id="$i",sku="PROD-00$i",name="Product $i",price=$((i * 10)).00 \
        --project="$PROJECT_ID" 2>/dev/null && echo "  Successfully inserted product $i" || echo "  Warning: Failed to insert product $i (may already exist)"
done

echo ""
echo "Inserting test orders..."
echo ""

# Insert test orders
for i in {1..3}; do
    echo "Inserting order $i..."
    gcloud spanner rows insert \
        --instance="$INSTANCE_ID" \
        --database="$DATABASE_ID" \
        --table="orders" \
        --data=order_id="$i",customer_id="$i",product_id="$i",quantity=$((i * 2)),status="PENDING" \
        --project="$PROJECT_ID" 2>/dev/null && echo "  Successfully inserted order $i" || echo "  Warning: Failed to insert order $i (may already exist)"
done

echo ""
echo "=================================================="
echo "Test Data Insertion Complete!"
echo "=================================================="
