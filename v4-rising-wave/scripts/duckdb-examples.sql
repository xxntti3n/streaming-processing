-- ============================================================================
-- DUCKDB ICEBERG EXAMPLE QUERIES
-- ============================================================================

-- SETUP: Run this first
INSTALL iceberg;
LOAD iceberg;

CREATE SECRET minio_creds (
    TYPE S3,
    KEY_ID 'hummockadmin',
    SECRET 'hummockadmin',
    ENDPOINT 'minio:9301',
    URL_STYLE 'path',
    REGION 'us-east-1',
    USE_SSL 'false'
);

CREATE VIEW customers AS
SELECT * FROM iceberg_scan('s3://hummock001/risingwave-iceberg/019d2062-eaa4-7e71-a2ce-5d0324b1d112/019d2062-eab5-7ef3-b263-e67a7cef592d/metadata/00002-019d2062-ef30-7d91-bbda-c9ac6a63ba90.gz.metadata.json');

CREATE VIEW orders AS
SELECT * FROM iceberg_scan('s3://hummock001/risingwave-iceberg/019d2062-eaa4-7e71-a2ce-5d0324b1d112/019d2062-fe4b-78f3-8f6c-4825f1dc0385/metadata/00002-019d2063-02be-7d40-828e-0936e787ca8d.gz.metadata.json');

-- ============================================================================
-- 1. BASIC QUERIES
-- ============================================================================

-- All customers
-- SELECT * FROM customers;

-- All orders
-- SELECT * FROM orders;

-- Top 5 orders by amount
-- SELECT * FROM orders ORDER BY amount DESC LIMIT 5;

-- ============================================================================
-- 2. FILTERING
-- ============================================================================

-- High value orders (> $100)
-- SELECT c.name, o.amount, o.status
-- FROM customers c JOIN orders o ON c.id = o.customer_id
-- WHERE o.amount >= 100
-- ORDER BY o.amount DESC;

-- Pending orders
-- SELECT c.name, o.amount, o.order_date
-- FROM customers c JOIN orders o ON c.id = o.customer_id
-- WHERE o.status = 'pending'
-- ORDER BY o.order_date;

-- Orders in a date range
-- SELECT * FROM orders
-- WHERE order_date BETWEEN '2025-01-15' AND '2025-01-17'
-- ORDER BY order_date, amount;

-- Multiple conditions
-- SELECT * FROM orders
-- WHERE amount > 50 AND status IN ('completed', 'shipped')
-- ORDER BY amount DESC;

-- ============================================================================
-- 3. AGGREGATION & GROUP BY
-- ============================================================================

-- Total revenue by customer
-- SELECT c.name, COUNT(o.id) as order_count, SUM(o.amount) as total_spent
-- FROM customers c JOIN orders o ON c.id = o.customer_id
-- GROUP BY c.name
-- ORDER BY total_spent DESC;

-- Revenue by status
-- SELECT status, COUNT(*) as orders, SUM(amount) as revenue, AVG(amount) as avg_order
-- FROM orders
-- GROUP BY status
-- ORDER BY revenue DESC;

-- Daily revenue
-- SELECT order_date, COUNT(*) as orders, SUM(amount) as revenue
-- FROM orders
-- GROUP BY order_date
-- ORDER BY order_date;

-- Customer spending tiers
-- SELECT
--     c.name,
--     SUM(o.amount) as total_spent,
--     CASE
--         WHEN SUM(o.amount) < 100 THEN 'Bronze'
--         WHEN SUM(o.amount) < 500 THEN 'Silver'
--         ELSE 'Gold'
--     END as tier
-- FROM customers c JOIN orders o ON c.id = o.customer_id
-- GROUP BY c.name
-- ORDER BY total_spent DESC;

-- ============================================================================
-- 4. WINDOW FUNCTIONS
-- ============================================================================

-- Customer ranking by spending
-- SELECT
--     name,
--     total_spent,
--     RANK() OVER (ORDER BY total_spent DESC) as rank
-- FROM (
--     SELECT c.name, SUM(o.amount) as total_spent
--     FROM customers c JOIN orders o ON c.id = o.customer_id
--     GROUP BY c.name
-- );

-- Running total of orders by date
-- SELECT
--     order_date,
--     SUM(amount) as daily_revenue,
--     SUM(SUM(amount)) OVER (ORDER BY order_date) as cumulative_revenue
-- FROM orders
-- GROUP BY order_date
-- ORDER BY order_date;

-- Top 2 orders per customer
-- SELECT * FROM (
--     SELECT
--         c.name,
--         o.amount,
--         o.status,
--         ROW_NUMBER() OVER (PARTITION BY c.id ORDER BY o.amount DESC) as rn
--     FROM customers c JOIN orders o ON c.id = o.customer_id
-- ) WHERE rn <= 2
-- ORDER BY name, amount DESC;

-- ============================================================================
-- 5. JOIN EXAMPLES
-- ============================================================================

-- Customers with their orders (INNER JOIN)
-- SELECT c.name, o.id, o.amount, o.status
-- FROM customers c
-- INNER JOIN orders o ON c.id = o.customer_id
-- ORDER BY c.name, o.amount DESC;

-- All customers, even those without orders (LEFT JOIN)
-- SELECT c.name, COUNT(o.id) as order_count, COALESCE(SUM(o.amount), 0) as total
-- FROM customers c
-- LEFT JOIN orders o ON c.id = o.customer_id
-- GROUP BY c.name
-- ORDER BY total DESC;

-- Find customers with no orders
-- SELECT c.name, c.email
-- FROM customers c
-- LEFT JOIN orders o ON c.id = o.customer_id
-- WHERE o.id IS NULL;

-- Self-join: Find orders with same amount
-- SELECT
--     o1.id as order_id_1,
--     o2.id as order_id_2,
--     o1.amount
-- FROM orders o1
-- JOIN orders o2 ON o1.amount = o2.amount AND o1.id < o2.id;

-- ============================================================================
-- 6. SUBQUERIES & CTEs
-- ============================================================================

-- Customers above average spending
-- WITH customer_spending AS (
--     SELECT c.name, SUM(o.amount) as total
--     FROM customers c JOIN orders o ON c.id = o.customer_id
--     GROUP BY c.name
-- )
-- SELECT name, total
-- FROM customer_spending
-- WHERE total > (SELECT AVG(total) FROM customer_spending)
-- ORDER BY total DESC;

-- Orders larger than customer's average
-- WITH customer_avg AS (
--     SELECT c.id, AVG(o.amount) as avg_order
--     FROM customers c JOIN orders o ON c.id = o.customer_id
--     GROUP BY c.id
-- )
-- SELECT c.name, o.id, o.amount, ca.avg_order
-- FROM customers c
-- JOIN orders o ON c.id = o.customer_id
-- JOIN customer_avg ca ON c.id = ca.id
-- WHERE o.amount > ca.avg_order
-- ORDER BY o.amount DESC;

-- ============================================================================
-- 7. DATE & TIME FUNCTIONS
-- ============================================================================

-- Orders by day of week (if you had timestamps)
-- SELECT
--     order_date,
--     DAYOFWEEK(order_date) as day_of_week,
--     COUNT(*) as orders,
--     SUM(amount) as revenue
-- FROM orders
-- GROUP BY order_date, DAYOFWEEK(order_date)
-- ORDER BY order_date;

-- Date arithmetic
-- SELECT
--     order_date,
--     CURRENT_DATE - order_date as days_ago,
--     DATE_TRUNC('month', order_date) as month
-- FROM orders
-- ORDER BY order_date DESC;

-- ============================================================================
-- 8. STRING OPERATIONS
-- ============================================================================

-- Search customers by name pattern
-- SELECT * FROM customers WHERE name LIKE '%Smith%';

-- Extract domain from email
-- SELECT
--     name,
--     email,
--     SPLIT_PART(email, '@', 2) as email_domain
-- FROM customers;

-- ============================================================================
-- 9. SET OPERATIONS
-- ============================================================================

-- Customers who either placed large orders OR are named 'Alice'
-- SELECT DISTINCT c.name
-- FROM customers c
-- JOIN orders o ON c.id = o.customer_id
-- WHERE o.amount > 100
-- UNION
-- SELECT name FROM customers WHERE name LIKE '%Alice%';

-- ============================================================================
-- 10. ANALYTICAL QUERIES
-- ============================================================================

-- Percentile ranks of order amounts
-- SELECT
--     id,
--     amount,
--     PERCENT_RANK() OVER (ORDER BY amount) as percentile
-- FROM orders
-- ORDER BY amount DESC;

-- Moving average of daily revenue (3-day window)
-- WITH daily_revenue AS (
--     SELECT order_date, SUM(amount) as revenue
--     FROM orders
--     GROUP BY order_date
-- )
-- SELECT
--     order_date,
--     revenue,
--     AVG(revenue) OVER (ORDER BY order_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as moving_avg
-- FROM daily_revenue
-- ORDER BY order_date;

-- ============================================================================
-- 11. CONDITIONAL AGGREGATION
-- ============================================================================

-- Pivot: Revenue by status per customer
-- SELECT
--     c.name,
--     COALESCE(SUM(CASE WHEN o.status = 'completed' THEN o.amount END), 0) as completed_revenue,
--     COALESCE(SUM(CASE WHEN o.status = 'pending' THEN o.amount END), 0) as pending_revenue,
--     COALESCE(SUM(CASE WHEN o.status = 'shipped' THEN o.amount END), 0) as shipped_revenue,
--     SUM(o.amount) as total_revenue
-- FROM customers c
-- LEFT JOIN orders o ON c.id = o.customer_id
-- GROUP BY c.name
-- ORDER BY total_revenue DESC;

-- ============================================================================
-- 12. HAVING CLAUSE (filter groups)
-- ============================================================================

-- Customers with more than 1 order
-- SELECT c.name, COUNT(o.id) as order_count
-- FROM customers c
-- JOIN orders o ON c.id = o.customer_id
-- GROUP BY c.name
-- HAVING COUNT(o.id) > 1
-- ORDER BY order_count DESC;

-- Status with total revenue > $200
-- SELECT status, SUM(amount) as revenue
-- FROM orders
-- GROUP BY status
-- HAVING SUM(amount) > 200
-- ORDER BY revenue DESC;

-- ============================================================================
-- 13. DISTINCT & UNIQUE VALUES
-- ============================================================================

-- Unique order amounts
-- SELECT DISTINCT amount FROM orders ORDER BY amount DESC;

-- Count unique customers who placed orders
-- SELECT COUNT(DISTINCT customer_id) as unique_customers FROM orders;

-- ============================================================================
-- 14. ORDERING VARIATIONS
-- ============================================================================

-- Multiple sort orders
-- SELECT c.name, o.amount, o.status
-- FROM customers c JOIN orders o ON c.id = o.customer_id
-- ORDER BY c.name ASC, o.amount DESC;

-- Random sample
-- SELECT * FROM customers ORDER BY RANDOM() LIMIT 2;

-- ============================================================================
-- 15. EXPORT RESULTS
-- ============================================================================

-- Export to CSV
-- COPY (SELECT * FROM customers) TO 'customers.csv' (HEADER, DELIMITER ',');

-- Export to JSON
-- COPY (SELECT * FROM orders ORDER BY amount DESC) TO 'orders.json';

-- Export to Parquet
-- COPY (SELECT c.name, o.amount, o.status FROM customers c JOIN orders o ON c.id = o.customer_id)
-- TO 'customer_orders.parquet';
