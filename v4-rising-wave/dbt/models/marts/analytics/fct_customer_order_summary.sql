-- Mart: Customer order summary fact table
-- Real-time aggregation of customer order metrics

{{ config(
    materialized='materialized_view',
    schema='marts'
) }}

{# Note: Indexes removed - 'include' not supported by risingwave adapter #}

SELECT
    c.customer_id,
    c.customer_name,
    c.customer_email,
    COUNT(o.order_id) AS order_count,
    COALESCE(SUM(o.amount), 0) AS total_spent,
    COALESCE(AVG(o.amount), 0) AS avg_order_amount,
    MAX(o.order_date) AS last_order_date
FROM {{ ref('stg_customers') }} c
LEFT JOIN {{ ref('stg_orders') }} o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.customer_name,
    c.customer_email
