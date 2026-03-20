#!/bin/bash
# Simple Spanner setup using Python container on kind network
set -e

echo "Setting up Spanner..."

# Kill any existing setup containers
docker rm -f spanner-setup 2>/dev/null || true

# Run a Python container connected to kind network
docker run --name spanner-setup --rm --network kind \
  -e SPANNER_EMULATOR_HOST=spanner-emulator:9010 \
  python:3.11-slim bash -c '
pip install grpcio==1.60.0 google-cloud-spanner==3.40.0 -q 2>&1 | grep -v "WARNING" || true

python3 -c "
import os
import sys
import grpc

# Set emulator host BEFORE importing google.cloud.spanner
os.environ[\"SPANNER_EMULATOR_HOST\"] = \"spanner-emulator:9010\"

from google.cloud import spanner
from google.auth.credentials import AnonymousCredentials

# Force using emulator without SSL
import google.cloud.spanner_admin_instance_v1
import google.cloud.spanner_admin_database_v1

# Create clients with direct emulator channel
spanner_client = spanner.Client(project=\"test-project\")

# Monkey-patch to use insecure channel for emulator
original_channel = None

def make_insecure_channel(target):
    return grpc.insecure_channel(target)

# Try to create instance
print(\"Creating instance...\")
try:
    from google.cloud.spanner_admin_instance_v1 import InstanceAdminClient, types
    import grpc

    # Direct gRPC call
    channel = grpc.insecure_channel(\"spanner-emulator:9010\")

    # Import and use the protobuf directly
    from google.cloud.spanner_admin_instance_v1 import instance_pb2, instance_pb2_grpc

    stub = spanner_instance_admin_pb2_grpc.InstanceAdminStub(channel)

    # Create instance request
    request = spanner_instance_admin_pb2.CreateInstanceRequest(
        parent=\"projects/test-project\",
        instance_id=\"test-instance\",
        instance=spanner_instance_admin_pb2.Instance(
            config=\"projects/test-project/instanceConfigs/emulator-config\",
            display_name=\"Test Instance\",
            node_count=1
        )
    )

    try:
        response = stub.CreateInstance(request)
        print(f\"Instance creation started: {response.operation.name}\")
    except grpc.RpcError as e:
        if e.code() == grpc.StatusCode.ALREADY_EXISTS:
            print(\"Instance already exists\")
        else:
            print(f\"Error creating instance: {e.details()}\")

    channel.close()

except Exception as e:
    print(f\"Error: {e}\")

# Create database and tables
print(\"Creating database and tables...\")
try:
    from google.cloud.spanner_admin_database_v1.proto import spanner_database_admin_pb2, spanner_database_admin_pb2_grpc
    import grpc

    channel = grpc.insecure_channel(\"spanner-emulator:9010\")
    stub = spanner_database_admin_pb2_grpc.DatabaseAdminStub(channel)

    request = spanner_database_admin_pb2.CreateDatabaseRequest(
        parent=\"projects/test-project/instances/test-instance\",
        create_statement=\"CREATE DATABASE ecommerce\",
        extra_statements=[
            \"\"\"CREATE TABLE customers (
                customer_id INT64 NOT NULL,
                email STRING(100),
                name STRING(100),
                created_at TIMESTAMP,
                updated_at TIMESTAMP
            ) PRIMARY KEY (customer_id)\"\"\",
            \"\"\"CREATE TABLE products (
                product_id INT64 NOT NULL,
                sku STRING(50),
                name STRING(200),
                price NUMERIC,
                category STRING(50),
                created_at TIMESTAMP
            ) PRIMARY KEY (product_id)\"\"\",
            \"\"\"CREATE TABLE orders (
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
            ) PRIMARY KEY (order_id)\"\"\",
            \"\"\"CREATE CHANGE STREAM ecommerce_change_stream
            FOR customers, products, orders
            OPTIONS (
                retention_period = \\\"1h\\\",
                capture_value_change_type = \\\"NEW_ROW_AND_OLD_ROW\\\"
            )\"\"\"
        ]
    )

    try:
        response = stub.CreateDatabase(request)
        print(f\"Database creation started: {response.operation.name}\")
    except grpc.RpcError as e:
        if e.code() == grpc.StatusCode.ALREADY_EXISTS:
            print(\"Database already exists\")
        else:
            print(f\"Error creating database: {e.details()}\")

    channel.close()

except Exception as e:
    print(f\"Error: {e}\")

print(\"\")
print(\"=== Verification ===\")

# List instances
try:
    from google.cloud.spanner_admin_instance_v1.proto import spanner_instance_admin_pb2, spanner_instance_admin_pb2_grpc
    import grpc

    channel = grpc.insecure_channel(\"spanner-emulator:9010\")
    stub = spanner_instance_admin_pb2_grpc.InstanceAdminStub(channel)

    request = spanner_instance_admin_pb2.ListInstancesRequest(
        parent=\"projects/test-project\"
    )
    response = stub.ListInstances(request)

    print(\"Instances:\")
    for inst in response.instances:
        print(f\"  - {inst.name} ({inst.display_name})\")

    channel.close()
except Exception as e:
    print(f\"Error listing instances: {e}\")

# List databases
try:
    from google.cloud.spanner_admin_database_v1.proto import spanner_database_admin_pb2, spanner_database_admin_pb2_grpc
    import grpc

    channel = grpc.insecure_channel(\"spanner-emulator:9010\")
    stub = spanner_database_admin_pb2_grpc.DatabaseAdminStub(channel)

    request = spanner_database_admin_pb2.ListDatabasesRequest(
        parent=\"projects/test-project/instances/test-instance\"
    )
    response = stub.ListDatabases(request)

    print(\"Databases:\")
    for db in response.databases:
        print(f\"  - {db.name}\")

    channel.close()
except Exception as e:
    print(f\"Error listing databases: {e}\")

print(\"\")
print(\"Setup complete!\")
"
' 2>&1 | grep -v "WARNING\|FutureWarning\|NotOpenSSLWarning" || true

echo ""
echo "Done!"
