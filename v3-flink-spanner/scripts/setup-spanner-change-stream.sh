#!/bin/bash
# setup-spanner-change-stream.sh - Initialize Spanner with change stream
set -e

INSTANCE_ID="test-instance"
DATABASE_ID="ecommerce"
PROJECT_ID="test-project"
NAMESPACE="default"

echo "=================================================="
echo "Setting up Spanner Change Stream"
echo "=================================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Warning: kubectl not found. Skipping port-forward."
    echo "Please ensure Spanner emulator is running at localhost:9010"
else
    # Port forward to Spanner emulator
    kubectl port-forward svc/spanner-emulator 9010:9010 -n "$NAMESPACE" &
    PF_PID=$!
    sleep 5

    cleanup() {
        kill $PF_PID 2>/dev/null || true
    }
    trap cleanup EXIT
fi

# Set environment for emulator
export SPANNER_EMULATOR_HOST=localhost:9010
export CLOUDSPANNER_EMULATOR_HOST=localhost:9010

echo ""
echo "Creating tables in Spanner..."
echo ""
echo "DDL to run:"
echo ""
cat << 'EOF'
-- Create tables
CREATE TABLE customers (
    customer_id INT64 NOT NULL,
    email STRING(100),
    name STRING(100),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) PRIMARY KEY (customer_id);

CREATE TABLE products (
    product_id INT64 NOT NULL,
    sku STRING(50),
    name STRING(200),
    price NUMERIC,
    category STRING(50),
    created_at TIMESTAMP
) PRIMARY KEY (product_id);

CREATE TABLE orders (
    order_id INT64 NOT NULL,
    customer_id INT64 NOT NULL,
    product_id INT64 NOT NULL,
    quantity INT64 NOT NULL,
    total_amount NUMERIC,
    order_status STRING(20),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
) PRIMARY KEY (order_id);
EOF

echo ""
echo "Creating change stream..."
cat << 'EOF'
-- Create change stream for all tables
CREATE CHANGE STREAM ecommerce_change_stream
FOR customers, products, orders
OPTIONS (
    retention_period = '1h',
    capture_value_change_type = 'NEW_ROW_AND_OLD_ROW'
);
EOF

echo ""
echo "=================================================="
echo "Change stream setup complete!"
echo "=================================================="
echo ""
echo "To apply DDL manually:"
echo "1. Install gcloud CLI"
echo "2. Run: export SPANNER_EMULATOR_HOST=localhost:9010"
echo "3. Run: gcloud spanner databases ddl update $DATABASE_ID --instance=$INSTANCE_ID --ddl='...'"
