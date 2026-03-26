-- Staging model for orders CDC data
-- This creates a materialized view that tracks orders in real-time

{{ config(
    materialized='materialized_view',
    schema='staging'
) }}

SELECT
    id AS order_id,
    customer_id,
    order_date,
    amount,
    status,
    created_at AS order_created_at
FROM {{ source('raw', 'orders_cdc') }}
