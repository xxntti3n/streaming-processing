-- ============================================================================
-- RisingWave CDC Source and JDBC Sink Configuration
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
-- JDBC Sinks (Write CDC data back to PostgreSQL)
-- ============================================================================

-- Customers JDBC Sink
CREATE SINK IF NOT EXISTS customers_jdbc_sink
FROM customers_cdc
WITH (
    connector = 'jdbc',
    type = 'upsert',
    jdbc.url = 'jdbc:postgresql://postgres:5432/mydb?user=postgres&password=postgres',
    table.name = 'customers_sink',
    primary_key = 'id'
);

-- Orders JDBC Sink
CREATE SINK IF NOT EXISTS orders_jdbc_sink
FROM orders_cdc
WITH (
    connector = 'jdbc',
    type = 'upsert',
    jdbc.url = 'jdbc:postgresql://postgres:5432/mydb?user=postgres&password=postgres',
    table.name = 'orders_sink',
    primary_key = 'id'
);
