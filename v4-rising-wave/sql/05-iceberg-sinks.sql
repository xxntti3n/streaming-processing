-- ============================================================================
-- RisingWave Iceberg Sinks Configuration
-- ============================================================================
-- This file creates Iceberg sinks that write CDC data to Iceberg tables
-- stored in MinIO via Lakekeeper REST catalog
-- ============================================================================

-- Set CDC options for better behavior
SET sink_decouple = false;

-- ============================================================================
-- Customers Iceberg Sink
-- ============================================================================
-- Writes customers CDC data to Iceberg table: analytics.customers
-- Location: s3://hummock001/risingwave-iceberg/
-- Commit interval: 1 second (near real-time)
-- ============================================================================

CREATE SINK IF NOT EXISTS customers_iceberg_sink
FROM customers_cdc
WITH (
    connector = 'iceberg',
    type = 'upsert',
    catalog.type = 'rest',
    catalog.uri = 'http://lakekeeper:8181/catalog/',
    warehouse.path = 'risingwave-warehouse',
    database.name = 'analytics',
    table.name = 'customers',
    s3.access.key = 'hummockadmin',
    s3.secret.key = 'hummockadmin',
    s3.endpoint = 'http://minio:9301',
    s3.region = 'us-east-1',
    s3.path.style.access = 'true',
    primary_key = 'id',
    commit_checkpoint_interval = '1'
);

-- ============================================================================
-- Orders Iceberg Sink
-- ============================================================================
-- Writes orders CDC data to Iceberg table: analytics.orders
-- Location: s3://hummock001/risingwave-iceberg/
-- Commit interval: 1 second (near real-time)
-- ============================================================================

CREATE SINK IF NOT EXISTS orders_iceberg_sink
FROM orders_cdc
WITH (
    connector = 'iceberg',
    type = 'upsert',
    catalog.type = 'rest',
    catalog.uri = 'http://lakekeeper:8181/catalog/',
    warehouse.path = 'risingwave-warehouse',
    database.name = 'analytics',
    table.name = 'orders',
    s3.access.key = 'hummockadmin',
    s3.secret.key = 'hummockadmin',
    s3.endpoint = 'http://minio:9301',
    s3.region = 'us-east-1',
    s3.path.style.access = 'true',
    primary_key = 'id',
    commit_checkpoint_interval = '1'
);

-- ============================================================================
-- Verification: Iceberg Source Tables (for querying the Iceberg data)
-- ============================================================================
-- These tables allow us to query the Iceberg data to verify the sinks
-- ============================================================================

CREATE TABLE IF NOT EXISTS customers_iceberg_verify (
    id BIGINT,
    name VARCHAR,
    email VARCHAR,
    created_at TIMESTAMP
) WITH (
    connector = 'iceberg',
    catalog.type = 'rest',
    catalog.uri = 'http://lakekeeper:8181/catalog/',
    warehouse.path = 'risingwave-warehouse',
    database.name = 'analytics',
    table.name = 'customers',
    s3.access.key = 'hummockadmin',
    s3.secret.key = 'hummockadmin',
    s3.endpoint = 'http://minio:9301',
    s3.region = 'us-east-1',
    s3.path.style.access = 'true'
);

CREATE TABLE IF NOT EXISTS orders_iceberg_verify (
    id BIGINT,
    customer_id BIGINT,
    order_date DATE,
    amount DECIMAL,
    status VARCHAR,
    created_at TIMESTAMP
) WITH (
    connector = 'iceberg',
    catalog.type = 'rest',
    catalog.uri = 'http://lakekeeper:8181/catalog/',
    warehouse.path = 'risingwave-warehouse',
    database.name = 'analytics',
    table.name = 'orders',
    s3.access.key = 'hummockadmin',
    s3.secret.key = 'hummockadmin',
    s3.endpoint = 'http://minio:9301',
    s3.region = 'us-east-1',
    s3.path.style.access = 'true'
);

-- Display created sinks
\echo '=== Iceberg Sinks Created ==='
SHOW SINKS;
