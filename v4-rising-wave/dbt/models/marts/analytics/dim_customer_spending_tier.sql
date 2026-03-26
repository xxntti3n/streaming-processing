-- Mart: Customer spending tier classification
-- Bronze: < $100, Silver: $100-$500, Gold: >= $500

{{ config(
    materialized='materialized_view',
    schema='marts'
) }}

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
    END AS customer_tier
FROM {{ ref('fct_customer_order_summary') }}
