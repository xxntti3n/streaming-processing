-- ============================================================================
-- DUCKDB TO ICEBERG CONNECTION - FINAL WORKING VERSION
-- ============================================================================

-- Step 1: Install and load extensions
INSTALL iceberg;
LOAD iceberg;

-- Step 2: Create S3 secret for MinIO access
CREATE SECRET minio_creds (
    TYPE S3,
    KEY_ID 'hummockadmin',
    SECRET 'hummockadmin',
    ENDPOINT 'minio:9301',
    URL_STYLE 'path',
    REGION 'us-east-1',
    USE_SSL 'false'
);

-- ============================================================================
-- CREATE VIEWS FOR EACH TABLE
-- ============================================================================

-- Customers view
CREATE OR REPLACE VIEW customers AS
SELECT * FROM iceberg_scan('s3://hummock001/risingwave-iceberg/019d2062-eaa4-7e71-a2ce-5d0324b1d112/019d2062-eab5-7ef3-b263-e67a7cef592d/metadata/00002-019d2062-ef30-7d91-bbda-c9ac6a63ba90.gz.metadata.json');

-- Orders view
CREATE OR REPLACE VIEW orders AS
SELECT * FROM iceberg_scan('s3://hummock001/risingwave-iceberg/019d2062-eaa4-7e71-a2ce-5d0324b1d112/019d2062-fe4b-78f3-8f6c-4825f1dc0385/metadata/00002-019d2063-02be-7d40-828e-0936e787ca8d.gz.metadata.json');

-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================

-- All customers
-- SELECT * FROM customers;

-- All orders
-- SELECT * FROM orders;

-- Customer order summary
SELECT
    c.name,
    c.email,
    COUNT(o.id) as order_count,
    COALESCE(SUM(o.amount), 0) as total_spent,
    COALESCE(AVG(o.amount), 0) as avg_order
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.name, c.email
ORDER BY total_spent DESC;

-- High value orders (> $100)
SELECT
    c.name,
    o.amount,
    o.status,
    o.order_date
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id
WHERE o.amount > 100
ORDER BY o.amount DESC;

-- Order status breakdown
SELECT
    status,
    COUNT(*) as order_count,
    SUM(amount) as total_amount
FROM orders
GROUP BY status
ORDER BY total_amount DESC;
