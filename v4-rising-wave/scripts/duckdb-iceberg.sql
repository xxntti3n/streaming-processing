-- DuckDB Iceberg Connection Script
-- Connects to Lakekeeper REST Catalog to read Iceberg tables

-- ============================================================================
-- INSTALL AND LOAD ICEBERG EXTENSION
-- ============================================================================

INSTALL iceberg;
LOAD iceberg;

-- ============================================================================
-- CONNECT TO LAKEKEEPER (REST CATALOG)
-- ============================================================================

-- Option 1: Using REST catalog connection (recommended)
-- This uses Lakekeeper's REST API to discover table metadata

-- First, create a secret for S3 access
CREATE SECRET minio_secret (
    TYPE S3,
    KEY_ID 'hummockadmin',
    SECRET 'hummockadmin',
    ENDPOINT 'http://localhost:9301',
    URL_STYLE 'path',
    REGION 'us-east-1'
);

-- Attach to Iceberg catalog via Lakekeeper REST API
-- DuckDB will use the REST catalog to discover tables
-- Note: DuckDB's iceberg extension currently has limited REST catalog support
-- Alternative: Use direct S3 path

-- ============================================================================
-- OPTION 2: DIRECT S3 PATH (works better with current DuckDB)
-- ============================================================================

-- Query customers table directly from S3
SELECT * FROM 's3://hummock001/risingwave-iceberg/019d2062-eaa4-7e71-a2ce-5d0324b1d112/019d2062-eab5-7ef3-b263-e67a7cef592d/metadata/*.metadata.json'
;

-- Query orders table
SELECT * FROM read_iceberg('s3://hummock001/risingwave-iceberg/*orders*/metadata/*.metadata.json');

-- ============================================================================
-- OPTION 3: USING LAKEKEEPER HTTP PROXY (if available)
-- ============================================================================

-- If Lakekeeper provides HTTP access to metadata files:
-- SELECT * FROM read_iceberg('http://localhost:8181/s3/hummock001/.../metadata/*.json');

-- ============================================================================
-- EXAMPLE QUERIES
-- ============================================================================

-- Get all customers
-- SELECT * FROM read_iceberg('s3://hummock001/risingwave-iceberg/*customers*/metadata/*.metadata.json');

-- Get all orders
-- SELECT * FROM read_iceberg('s3://hummock001/risingwave-iceberg/*orders*/metadata/*.metadata.json');

-- Join customers and orders
-- SELECT
--     c.name,
--     c.email,
--     o.amount,
--     o.status
-- FROM read_iceberg('s3://hummock001/risingwave-iceberg/*customers*/metadata/*.metadata.json') c
-- JOIN read_iceberg('s3://hummock001/risingwave-iceberg/*orders*/metadata/*.metadata.json') o
--     ON c.id = o.customer_id;
