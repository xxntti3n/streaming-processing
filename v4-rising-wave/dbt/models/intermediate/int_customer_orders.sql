-- Intermediate model joining customers with their orders
-- This creates a materialized view for enriched order data

{{ config(
    materialized='materialized_view',
    schema='intermediate'
) }}

SELECT
    o.order_id,
    o.customer_id,
    c.customer_name,
    c.customer_email,
    o.amount,
    o.order_date,
    o.status,
    o.order_created_at
FROM {{ ref('stg_orders') }} o
INNER JOIN {{ ref('stg_customers') }} c
    ON o.customer_id = c.customer_id
