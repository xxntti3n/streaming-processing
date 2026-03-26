-- Mart: Daily order metrics
-- Time-windowed daily aggregations

{{ config(
    materialized='materialized_view',
    schema='marts'
) }}

SELECT
    DATE_TRUNC('day', order_created_at) AS metric_date,
    COUNT(*) AS total_orders,
    SUM(amount) AS daily_revenue,
    AVG(amount) AS avg_order_value,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM {{ ref('stg_orders') }}
GROUP BY DATE_TRUNC('day', order_created_at)
