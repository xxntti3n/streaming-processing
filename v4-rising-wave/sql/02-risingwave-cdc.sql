-- ============================================================================
-- RisingWave CDC Source and Iceberg Sink Configuration
-- ============================================================================

-- Set CDC options for better behavior
SET sink_decouple = false;

-- ============================================================================
-- Secrets Management
-- ============================================================================

-- PostgreSQL password secret
CREATE SECRET IF NOT EXISTS postgres_pwd WITH (
    backend = 'meta'
) AS 'postgres';

-- MinIO access key secret
CREATE SECRET IF NOT EXISTS minio_access_key WITH (
    backend = 'meta'
) AS 'hummockadmin';

-- MinIO secret key secret
CREATE SECRET IF NOT EXISTS minio_secret_key WITH (
    backend = 'meta'
) AS 'hummockadmin';

-- ============================================================================
-- PostgreSQL CDC Sources
-- ============================================================================

-- Customers CDC Source
CREATE TABLE IF NOT EXISTS customers_cdc (
    id BIGINT PRIMARY KEY,
    name VARCHAR,
    email VARCHAR,
    created_at TIMESTAMP
) WITH (
    connector = 'postgres-cdc',
    hostname = 'postgres',
    port = '5432',
    username = 'postgres',
    password = SECRET postgres_pwd,
    database.name = 'mydb',
    schema.name = 'public',
    table.name = 'customers',
    slot.name = 'customers_cdc_slot'
);

-- Orders CDC Source
CREATE TABLE IF NOT EXISTS orders_cdc (
    id BIGINT PRIMARY KEY,
    customer_id BIGINT,
    order_date DATE,
    amount DECIMAL,
    status VARCHAR,
    created_at TIMESTAMP
) WITH (
    connector = 'postgres-cdc',
    hostname = 'postgres',
    port = '5432',
    username = 'postgres',
    password = SECRET postgres_pwd,
    database.name = 'mydb',
    schema.name = 'public',
    table.name = 'orders',
    slot.name = 'orders_cdc_slot'
);

-- ============================================================================
-- Iceberg Sinks
-- ============================================================================

-- Customers Iceberg Sink
CREATE SINK IF NOT EXISTS customers_iceberg_sink
WITH (
    connector = 'iceberg',
    type = 'upsert',
    primary_key = 'id',
    warehouse.path = 's3a://iceberg-data',
    s3.endpoint = 'http://minio:9301',
    s3.access.key = SECRET minio_access_key,
    s3.secret.key = SECRET minio_secret_key,
    s3.region = 'us-east-1',
    catalog.type = 'storage',
    catalog.name = 'demo',
    database.name = 'mydb',
    table.name = 'customers',
    create_table_if_not_exists = 'true'
)
AS SELECT * FROM customers_cdc;

-- Orders Iceberg Sink
CREATE SINK IF NOT EXISTS orders_iceberg_sink
WITH (
    connector = 'iceberg',
    type = 'upsert',
    primary_key = 'id',
    warehouse.path = 's3a://iceberg-data',
    s3.endpoint = 'http://minio:9301',
    s3.access.key = SECRET minio_access_key,
    s3.secret.key = SECRET minio_secret_key,
    s3.region = 'us-east-1',
    catalog.type = 'storage',
    catalog.name = 'demo',
    database.name = 'mydb',
    table.name = 'orders',
    create_table_if_not_exists = 'true'
)
AS SELECT * FROM orders_cdc;