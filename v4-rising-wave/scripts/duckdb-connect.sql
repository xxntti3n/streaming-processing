-- ============================================================================
-- DUCKDB TO ICEBERG CONNECTION GUIDE
-- ============================================================================

-- Step 1: Install and load the Iceberg extension
INSTALL iceberg;
LOAD iceberg;

-- Step 2: Create S3 secret for MinIO access
CREATE SECRET minio_creds (
    TYPE S3,
    KEY_ID 'hummockadmin',
    SECRET 'hummockadmin',
    ENDPOINT 'http://localhost:9301',
    URL_STYLE 'path',
    REGION 'us-east-1'
);

-- Step 3: Query Iceberg tables directly from S3
-- Note: DuckDB reads the metadata.json files to discover the data files

-- ============================================================================
-- QUERY CUSTOMERS TABLE
-- ============================================================================

-- Method 1: Using glob pattern to find metadata files
SELECT * FROM read_iceberg('s3://hummock001/risingwave-iceberg/*customers*/metadata/*.metadata.json');

-- Method 2: If you know the exact metadata path (more reliable)
-- Replace with your actual path from Lakekeeper
SELECT * FROM read_iceberg('s3://hummock001/risingwave-iceberg/019d2062-eaa4-7e71-a2ce-5d0324b1d112/019d2062-eab5-7ef3-b263-e67a7cef592d/metadata/00002-019d2062-ef30-7d91-bbda-c9ac6a63ba90.gz.metadata.json');

-- ============================================================================
-- QUERY ORDERS TABLE
-- ============================================================================

SELECT * FROM read_iceberg('s3://hummock001/risingwave-iceberg/*orders*/metadata/*.metadata.json');

-- ============================================================================
-- EXAMPLE ANALYTICS QUERIES
-- ============================================================================

-- Customer order summary
SELECT
    c.name,
    c.email,
    COUNT(o.id) as order_count,
    COALESCE(SUM(o.amount), 0) as total_spent
FROM read_iceberg('s3://hummock001/risingwave-iceberg/*customers*/metadata/*.metadata.json') c
LEFT JOIN read_iceberg('s3://hummock001/risingwave-iceberg/*orders*/metadata/*.metadata.json') o
    ON c.id = o.customer_id
GROUP BY c.name, c.email
ORDER BY total_spent DESC;

-- High value orders (> $100)
SELECT
    c.name,
    o.amount,
    o.status,
    o.order_date
FROM read_iceberg('s3://hummock001/risingwave-iceberg/*customers*/metadata/*.metadata.json') c
INNER JOIN read_iceberg('s3://hummock001/risingwave-iceberg/*orders*/metadata/*.metadata.json') o
    ON c.id = o.customer_id
WHERE o.amount > 100
ORDER BY o.amount DESC;

-- ============================================================================
-- CREATE VIEWS FOR EASIER ACCESS
-- ============================================================================

-- Create a view for customers
CREATE OR REPLACE VIEW customers AS
SELECT * FROM read_iceberg('s3://hummock001/risingwave-iceberg/*customers*/metadata/*.metadata.json');

-- Create a view for orders
CREATE OR REPLACE VIEW orders AS
SELECT * FROM read_iceberg('s3://hummock001/risingwave-iceberg/*orders*/metadata/*.metadata.json');

-- Now you can query like regular tables
-- SELECT * FROM customers;
-- SELECT * FROM orders;
