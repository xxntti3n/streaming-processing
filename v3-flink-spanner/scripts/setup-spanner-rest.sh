#!/bin/bash
# Setup Spanner emulator using REST API
set -e

echo "Setting up Spanner via REST API..."

# Start port-forwards
kubectl port-forward svc/spanner-emulator 9010:9010 2>&1 &
PF1_PID=$!
kubectl port-forward svc/spanner-emulator 9020:9020 2>&1 &
PF2_PID=$!

sleep 3

# Use Python with requests library to talk to the REST API
python3 << 'PYEOF'
import requests
import json
import time

BASE_URL = "http://localhost:9020/v1"
PROJECT = "test-project"
INSTANCE = "test-instance"
DATABASE = "ecommerce"

def create_instance():
    """Create Spanner instance via REST API."""
    url = f"{BASE_URL}/projects/{PROJECT}/instances"
    data = {
        "instance": {
            "name": f"projects/{PROJECT}/instances/{INSTANCE}",
            "config": f"projects/{PROJECT}/instanceConfigs/emulator-config",
            "displayName": "Test Instance",
            "nodeCount": 1
        }
    }

    print(f"Creating instance {INSTANCE}...")
    response = requests.post(url, json=data)
    print(f"Response: {response.status_code}")

    if response.status_code == 409:
        print("Instance already exists")
    elif response.status_code == 200:
        print("Instance created")
    else:
        print(f"Error: {response.text}")

def create_database():
    """Create database via REST API."""
    url = f"{BASE_URL}/projects/{PROJECT}/instances/{INSTANCE}/databases"
    data = {
        "extraStatements": [
            "CREATE TABLE customers (customer_id INT64 NOT NULL, email STRING(100), name STRING(100), created_at TIMESTAMP, updated_at TIMESTAMP) PRIMARY KEY (customer_id)",
            "CREATE TABLE products (product_id INT64 NOT NULL, sku STRING(50), name STRING(200), price NUMERIC, category STRING(50), created_at TIMESTAMP) PRIMARY KEY (product_id)",
            "CREATE TABLE orders (order_id INT64 NOT NULL, customer_id INT64 NOT NULL, product_id INT64 NOT NULL, quantity INT64 NOT NULL, total_amount NUMERIC, order_status STRING(20), created_at TIMESTAMP, updated_at TIMESTAMP, FOREIGN KEY (customer_id) REFERENCES customers(customer_id), FOREIGN KEY (product_id) REFERENCES products(product_id)) PRIMARY KEY (order_id)",
            "CREATE CHANGE STREAM ecommerce_change_stream FOR customers, products, orders OPTIONS (retention_period = \"1h\", capture_value_change_type = \"NEW_ROW_AND_OLD_ROW\")"
        ]
    }

    print(f"\nCreating database {DATABASE}...")
    response = requests.post(url, json=data)
    print(f"Response: {response.status_code}")

    if response.status_code == 409:
        print("Database already exists")
    elif response.status_code == 200:
        result = response.json()
        print(f"Database creation started: {result.get('name', 'unknown')}")
        # Wait for operation to complete
        if 'name' in result:
            op_name = result['name']
            print(f"Waiting for operation {op_name}...")
            time.sleep(2)
    else:
        print(f"Error: {response.text}")

def list_instances():
    """List instances."""
    url = f"{BASE_URL}/projects/{PROJECT}/instances"
    response = requests.get(url)
    print(f"\n=== Instances ===")
    if response.status_code == 200:
        data = response.json()
        for instance in data.get('instances', []):
            print(f"  - {instance.get('name')}")
    else:
        print(f"Error: {response.text}")

def list_databases():
    """List databases."""
    url = f"{BASE_URL}/projects/{PROJECT}/instances/{INSTANCE}/databases"
    response = requests.get(url)
    print(f"\n=== Databases ===")
    if response.status_code == 200:
        data = response.json()
        for database in data.get('databases', []):
            print(f"  - {database.get('name')}")
    else:
        print(f"Error: {response.text}")

# Main
print("Spanner Emulator REST API Setup")
print("=" * 40)

create_instance()
time.sleep(1)
create_database()
time.sleep(1)
list_instances()
list_databases()

print("\nSetup complete!")
PYEOF

# Cleanup
kill $PF1_PID $PF2_PID 2>/dev/null

echo "Done!"
