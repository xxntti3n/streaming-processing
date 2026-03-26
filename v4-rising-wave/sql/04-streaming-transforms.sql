-- ============================================================================
-- Streaming Transformations for CDC Pipeline
-- ============================================================================
-- This file creates real-time analytics on top of the CDC data
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Customer Order Summary - Real-time aggregation per customer
-- ----------------------------------------------------------------------------
-- Provides: total_spent, order_count, avg_amount, last_order_date
CREATE MATERIALIZED VIEW customer_order_summary AS
SELECT
    c.id AS customer_id,
    c.name AS customer_name,
    c.email AS customer_email,
    COUNT(o.id) AS order_count,
    COALESCE(SUM(o.amount), 0) AS total_spent,
    COALESCE(AVG(o.amount), 0) AS avg_order_amount,
    MAX(o.order_date) AS last_order_date
FROM customers_cdc c
LEFT JOIN orders_cdc o ON c.id = o.customer_id
GROUP BY c.id, c.name, c.email;

-- ----------------------------------------------------------------------------
-- 2. High Value Orders Stream - Filter orders >= $100
-- ----------------------------------------------------------------------------
-- Routes high-value orders to a separate stream for special handling
CREATE MATERIALIZED VIEW high_value_orders AS
SELECT
    o.id AS order_id,
    o.customer_id,
    c.name AS customer_name,
    c.email AS customer_email,
    o.amount,
    o.order_date,
    o.status,
    o.created_at
FROM orders_cdc o
JOIN customers_cdc c ON o.customer_id = c.id
WHERE o.amount >= 100
WITH (emit_on_window_change = false);  -- Emit on every change

-- ----------------------------------------------------------------------------
-- 3. Order Status Dashboard - Real-time status counts
-- ----------------------------------------------------------------------------
-- Provides real-time breakdown of orders by status
CREATE MATERIALIZED VIEW order_status_dashboard AS
SELECT
    status,
    COUNT(*) AS order_count,
    SUM(amount) AS total_amount,
    AVG(amount) AS avg_amount,
    MIN(order_date) AS earliest_order,
    MAX(order_date) AS latest_order
FROM orders_cdc
GROUP BY status;

-- ----------------------------------------------------------------------------
-- 4. Daily Order Metrics - Tumbling window aggregation
-- ----------------------------------------------------------------------------
-- Daily totals using tumbling window
CREATE MATERIALIZED VIEW daily_order_metrics AS
SELECT
    DATE_TRUNC('day', created_at) AS date,
    COUNT(*) AS total_orders,
    SUM(amount) AS daily_revenue,
    AVG(amount) AS avg_order_value,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM orders_cdc
GROUP BY DATE_TRUNC('day', created_at);

-- ----------------------------------------------------------------------------
-- 5. Customer Spending Tier - Dynamic categorization
-- ----------------------------------------------------------------------------
-- Classify customers into spending tiers (Bronze < $100, Silver $100-$500, Gold > $500)
CREATE MATERIALIZED VIEW customer_spending_tier AS
SELECT
    customer_id,
    customer_name,
    customer_email,
    total_spent,
    order_count,
    CASE
        WHEN total_spent < 100 THEN 'Bronze'
        WHEN total_spent < 500 THEN 'Silver'
        ELSE 'Gold'
    END AS tier
FROM customer_order_summary;

-- ----------------------------------------------------------------------------
-- 6. Recent Orders Stream - Last 10 orders per customer
-- ----------------------------------------------------------------------------
-- Keeps track of recent activity for each customer
CREATE MATERIALIZED VIEW recent_orders AS
SELECT
    customer_id,
    customer_name,
    order_id,
    amount,
    status,
    created_at,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at DESC) AS rank
FROM (
    SELECT
        o.customer_id,
        c.name AS customer_name,
        o.id AS order_id,
        o.amount,
        o.status,
        o.created_at
    FROM orders_cdc o
    JOIN customers_cdc c ON o.customer_id = c.id
);

-- Display all created materialized views
SHOW MATERIALIZED VIEWS;
