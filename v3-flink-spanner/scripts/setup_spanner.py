#!/usr/bin/env python3
"""Setup Spanner emulator with database and tables."""
from google.cloud import spanner

spanner_client = spanner.Client(project='test-project')
spanner_client._emulator_host = 'localhost:9010'

print('Creating instance...')
config_name = 'projects/test-project/instanceConfigs/emulator-config'
instance = spanner_client.instance('test-instance', configuration_name=config_name)
try:
    instance.create()
    print('Instance created')
except Exception as e:
    if 'AlreadyExists' in str(e) or 'ALREADY_EXISTS' in str(e) or 'already exists' in str(e):
        print('Instance exists')
    else:
        print(f'Error creating instance: {e}')
        raise

print('Creating database...')
database = instance.database('ecommerce')

create_statements = [
    '''CREATE TABLE customers (
        customer_id INT64 NOT NULL,
        email STRING(100),
        name STRING(100),
        created_at TIMESTAMP,
        updated_at TIMESTAMP
    ) PRIMARY KEY (customer_id)''',
    '''CREATE TABLE products (
        product_id INT64 NOT NULL,
        sku STRING(50),
        name STRING(200),
        price NUMERIC,
        category STRING(50),
        created_at TIMESTAMP
    ) PRIMARY KEY (product_id)''',
    '''CREATE TABLE orders (
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
    ) PRIMARY KEY (order_id)''',
    '''CREATE CHANGE STREAM ecommerce_change_stream
    FOR customers, products, orders
    OPTIONS (
        retention_period = "1h",
        capture_value_change_type = "NEW_ROW_AND_OLD_ROW"
    )'''
]

try:
    # Use the instance's internal database admin
    db_admin = instance._instance_admin_client.database_admin

    # Create database request
    from google.cloud.spanner_admin_database_v1.types import CreateDatabaseRequest
    request = CreateDatabaseRequest(
        parent=instance.name,
        create_statement='CREATE DATABASE ecommerce',
        extra_statements=create_statements
    )

    op = db_admin.create_database(request)
    op.result()
    print('Database created successfully')
except Exception as e:
    if 'AlreadyExists' in str(e):
        print('Database already exists')
    else:
        print(f'Error creating database: {e}')
        raise

print('Setup complete!')
