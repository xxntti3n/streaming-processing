#!/bin/bash
# Setup Spanner emulator using Docker with gcloud CLI
set -e

echo "Starting Spanner setup..."

# Get the Spanner emulator pod IP
SPANNER_POD=$(kubectl get pod -l app=spanner-emulator -o jsonpath='{.items[0].metadata.name}')
SPANNER_IP=$(kubectl get pod "$SPANNER_POD" -o jsonpath='{.status.podIP}')
echo "Spanner emulator at: $SPANNER_POD ($SPANNER_IP:9010)"

# Create a network to connect Docker container to kind network
docker network connect kind spanner-emulator-setup 2>/dev/null || true

# Run gcloud CLI container connected to kind network
docker run --rm --name spanner-emulator-setup \
  --network kind \
  -e SPANNER_EMULATOR_HOST=spanner-emulator:9010 \
  -e CLOUDSPANNER_EMULATOR_HOST=spanner-emulator:9010 \
  gcr.io/google.com/cloudsdktool/cloud-sdk:slim \
  bash -c "
    # Set project
    gcloud config set project test-project

    # Create fake ADC for emulator
    mkdir -p /tmp/.config/gcloud
    echo '{}' > /tmp/.config/gcloud/application_default_credentials.json
    export CLOUDSDK_CONFIG=/tmp/.config/gcloud

    echo 'Creating instance...'
    gcloud spanner instances create test-instance \\
      --config=emulator-config \\
      --description='Test Instance' || echo 'Instance may already exist'

    echo 'Creating database...'
    gcloud spanner databases create ecommerce \\
      --instance=test-instance || echo 'Database may already exist'

    echo 'Creating tables...'
    gcloud spanner databases ddl update ecommerce \\
      --instance=test-instance \\
      --ddl='
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

        CREATE CHANGE STREAM ecommerce_change_stream
        FOR customers, products, orders
        OPTIONS (
            retention_period = \"1h\",
            capture_value_change_type = \"NEW_ROW_AND_OLD_ROW\"
        );
      ' || echo 'Tables may already exist'

    echo ''
    echo '=== Verification ==='
    gcloud spanner instances list || echo 'List instances failed'
    echo ''
    gcloud spanner databases list --instance=test-instance || echo 'List databases failed'
    echo ''
    echo 'Spanner setup complete!'
  " || echo "Setup failed"

echo "Done!"
