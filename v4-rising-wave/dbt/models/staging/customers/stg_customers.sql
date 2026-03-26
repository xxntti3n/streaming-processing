-- Staging model for customers CDC data
-- This creates a materialized view that tracks customers in real-time

{{ config(
    materialized='materialized_view',
    schema='staging'
) }}

SELECT
    id AS customer_id,
    name AS customer_name,
    email AS customer_email,
    created_at AS customer_created_at
FROM {{ source('raw', 'customers_cdc') }}
