-- Mart: Order status dashboard
-- Real-time breakdown of orders by status

{{ config(
    materialized='materialized_view',
    schema='marts'
) }}

SELECT
    status,
    COUNT(*) AS order_count,
    SUM(amount) AS total_amount,
    AVG(amount) AS avg_amount,
    MIN(order_date) AS earliest_order,
    MAX(order_date) AS latest_order
FROM {{ ref('stg_orders') }}
GROUP BY status
