-- Mart: High value orders (>= $100)
-- Orders requiring special attention

{{ config(
    materialized='materialized_view',
    schema='marts'
) }}

SELECT
    order_id,
    customer_id,
    customer_name,
    customer_email,
    amount,
    order_date,
    status,
    order_created_at
FROM {{ ref('int_customer_orders') }}
WHERE amount >= 100
