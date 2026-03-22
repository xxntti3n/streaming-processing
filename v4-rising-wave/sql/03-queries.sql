-- ============================================================================
-- Verification Queries for PostgreSQL CDC to Iceberg Pipeline
-- ============================================================================

-- ============================================================================
-- 1. Check PostgreSQL Source Data
-- ============================================================================

\echo '=== PostgreSQL Source: Customers ==='
SELECT id, name, email FROM customers ORDER BY id;

\echo '=== PostgreSQL Source: Orders ==='
SELECT id, customer_id, order_date, amount, status FROM orders ORDER BY id;

-- ============================================================================
-- 2. Check RisingWave CDC Streams
-- ============================================================================

\echo '=== RisingWave CDC: Customers Stream ==='
SELECT id, name, email FROM customers_cdc ORDER BY id;

\echo '=== RisingWave CDC: Orders Stream ==='
SELECT id, customer_id, order_date, amount, status FROM orders_cdc ORDER BY id;

-- ============================================================================
-- 3. Check Iceberg Sink Statistics
-- ============================================================================

\echo '=== Iceberg Snapshots for Customers ==='
SELECT * FROM rw_iceberg_snapshots WHERE source_name = 'customers_iceberg_sink';

\echo '=== Iceberg Snapshots for Orders ==='
SELECT * FROM rw_iceberg_snapshots WHERE source_name = 'orders_iceberg_sink';

\echo '=== Iceberg Files for Customers ==='
SELECT * FROM rw_iceberg_files WHERE source_name = 'customers_iceberg_sink';

\echo '=== Iceberg Files for Orders ==='
SELECT * FROM rw_iceberg_files WHERE source_name = 'orders_iceberg_sink';

-- ============================================================================
-- 4. Row Count Verification
-- ============================================================================

\echo '=== Row Counts Comparison ==='
SELECT
    'customers_cdc' as source,
    COUNT(*) as row_count
FROM customers_cdc
UNION ALL
SELECT
    'orders_cdc' as source,
    COUNT(*) as row_count
FROM orders_cdc;