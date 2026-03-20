#!/usr/bin/env python3
"""Setup Spanner emulator using raw gRPC - no auth needed."""
import grpc
import time
from google.protobuf import empty_pb2

# Import spanner protobuf definitions
# We need to generate or import these - let's try using the protoc-generated files

try:
    # First try to use the grpc generated files from the google packages
    from grpc.beta import interfaces
    from google.cloud.spanner_admin_instance_v1 import instance_pb2, instance_pb2_grpc
    from google.cloud.spanner_admin_database_v1 import database_pb2, database_pb2_grpc
    from google.longrunning import operations_pb2, operations_pb2_grpc
except ImportError as e:
    print(f"Import error: {e}")
    print("Trying alternative import paths...")
    try:
        from google.cloud.spanner_v1 import instance_pb2, instance_pb2_grpc
        from google.cloud.spanner_v1 import spanner_pb2, spanner_pb2_grpc
    except ImportError:
        print("Cannot import spanner protobuf files")
        print("Falling back to manual protobuf compilation...")
        exit(1)

# Spanner emulator configuration
EMULATOR_HOST = "localhost:9010"
PROJECT_ID = "test-project"
INSTANCE_ID = "test-instance"
DATABASE_ID = "ecommerce"

def create_instance(stub):
    """Create Spanner instance."""
    from google.cloud.spanner.admin.instance.v1 import instance_pb2

    request = instance_pb2.CreateInstanceRequest(
        parent=f"projects/{PROJECT_ID}",
        instance_id=INSTANCE_ID,
        instance=instance_pb2.Instance(
            config=f"projects/{PROJECT_ID}/instanceConfigs/emulator-config",
            display_name="Test Instance",
            node_count=1
        )
    )

    try:
        response = stub.CreateInstance(request)
        print(f"Instance creation started: {response.operation.name}")
        return response.operation.name
    except grpc.RpcError as e:
        if e.code() == grpc.StatusCode.ALREADY_EXISTS:
            print("Instance already exists")
            return None
        else:
            print(f"Error creating instance: {e}")
            raise

def create_database(stub):
    """Create database with tables."""
    from google.cloud.spanner.admin.database.v1 import database_pb2

    request = database_pb2.CreateDatabaseRequest(
        parent=f"projects/{PROJECT_ID}/instances/{INSTANCE_ID}",
        create_statement=f"CREATE DATABASE `{DATABASE_ID}`",
        extra_statements=[
            """CREATE TABLE customers (
                customer_id INT64 NOT NULL,
                email STRING(100),
                name STRING(100),
                created_at TIMESTAMP,
                updated_at TIMESTAMP
            ) PRIMARY KEY (customer_id)""",
            """CREATE TABLE products (
                product_id INT64 NOT NULL,
                sku STRING(50),
                name STRING(200),
                price NUMERIC,
                category STRING(50),
                created_at TIMESTAMP
            ) PRIMARY KEY (product_id)""",
            """CREATE TABLE orders (
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
            ) PRIMARY KEY (order_id)""",
            """CREATE CHANGE STREAM ecommerce_change_stream
            FOR customers, products, orders
            OPTIONS (
                retention_period = "1h",
                capture_value_change_type = "NEW_ROW_AND_OLD_ROW"
            )"""
        ]
    )

    try:
        response = stub.CreateDatabase(request)
        print(f"Database creation started: {response.operation.name}")
        return response.operation.name
    except grpc.RpcError as e:
        if e.code() == grpc.StatusCode.ALREADY_EXISTS:
            print("Database already exists")
            return None
        else:
            print(f"Error creating database: {e}")
            raise

def wait_for_operation(operation_stub, operation_name):
    """Wait for long-running operation to complete."""
    from google.longrunning import operations_pb2

    request = operations_pb2.GetOperationRequest(name=operation_name)

    for _ in range(60):  # Wait up to 60 seconds
        try:
            response = operation_stub.GetOperation(request)
            if response.done:
                if response.HasField('error'):
                    print(f"Operation failed: {response.error.message}")
                    return False
                print("Operation completed successfully")
                return True
            time.sleep(1)
        except Exception as e:
            print(f"Error checking operation: {e}")
            time.sleep(1)

    print("Operation timed out")
    return False

def list_instances(stub):
    """List instances."""
    from google.cloud.spanner.admin.instance.v1 import instance_pb2

    request = instance_pb2.ListInstancesRequest(
        parent=f"projects/{PROJECT_ID}"
    )

    try:
        response = stub.ListInstances(request)
        print("\n=== Instances ===")
        for instance in response.instances:
            print(f"  - {instance.name} ({instance.display_name})")
        return True
    except Exception as e:
        print(f"Error listing instances: {e}")
        return False

def list_databases(stub):
    """List databases."""
    from google.cloud.spanner.admin.database.v1 import database_pb2

    request = database_pb2.ListDatabasesRequest(
        parent=f"projects/{PROJECT_ID}/instances/{INSTANCE_ID}"
    )

    try:
        response = stub.ListDatabases(request)
        print("\n=== Databases ===")
        for database in response.databases:
            print(f"  - {database.name}")
        return True
    except Exception as e:
        print(f"Error listing databases: {e}")
        return False

def main():
    print("Setting up Spanner emulator...")
    print(f"Emulator host: {EMULATOR_HOST}")

    # Create insecure gRPC channel
    channel = grpc.insecure_channel(EMULATOR_HOST)

    try:
        # Create stubs
        instance_stub = instance_pb2_grpc.InstanceAdminStub(channel)
        database_stub = database_pb2_grpc.DatabaseAdminStub(channel)
        operations_stub = operations_pb2_grpc.OperationsStub(channel)

        # Create instance
        print("\n--- Creating Instance ---")
        op_name = create_instance(instance_stub)
        if op_name:
            wait_for_operation(operations_stub, op_name)

        # Create database
        print("\n--- Creating Database ---")
        op_name = create_database(database_stub)
        if op_name:
            wait_for_operation(operations_stub, op_name)

        # Verify
        print("\n--- Verification ---")
        list_instances(instance_stub)
        list_databases(database_stub)

        print("\nSetup complete!")

    finally:
        channel.close()

if __name__ == "__main__":
    main()
