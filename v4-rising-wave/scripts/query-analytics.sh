#!/bin/bash
set -e

echo "=========================================="
echo "  Streaming Analytics Query Dashboard"
echo "=========================================="
echo ""

PSQL="docker exec postgres psql -h risingwave -p 4566 -d dev"

# 1. Customer Order Summary
echo "1. CUSTOMER ORDER SUMMARY"
echo "   Real-time customer spending aggregates"
echo "   ----------------------------------------"
$PSQL -c "
SELECT
    customer_id,
    customer_name,
    order_count,
    ROUND(total_spent::numeric, 2) AS total_spent,
    ROUND(avg_order_amount::numeric, 2) AS avg_amount,
    last_order_date
FROM customer_order_summary
ORDER BY total_spent DESC
LIMIT 10;
"
echo ""

# 2. High Value Orders
echo "2. HIGH VALUE ORDERS (>= $100)"
echo "   Orders requiring special attention"
echo "   ----------------------------------------"
$PSQL -c "
SELECT
    order_id,
    customer_name,
    ROUND(amount::numeric, 2) AS amount,
    status,
    created_at::date AS order_date
FROM high_value_orders
ORDER BY amount DESC
LIMIT 10;
"
echo ""

# 3. Order Status Dashboard
echo "3. ORDER STATUS DASHBOARD"
echo "   Real-time order breakdown by status"
echo "   ----------------------------------------"
$PSQL -c "
SELECT
    status,
    order_count,
    ROUND(total_amount::numeric, 2) AS total_amount,
    ROUND(avg_amount::numeric, 2) AS avg_amount
FROM order_status_dashboard
ORDER BY order_count DESC;
"
echo ""

# 4. Daily Metrics
echo "4. DAILY ORDER METRICS"
echo "   Time-windowed daily aggregations"
echo "   ----------------------------------------"
$PSQL -c "
SELECT
    date,
    total_orders,
    ROUND(daily_revenue::numeric, 2) AS revenue,
    ROUND(avg_order_value::numeric, 2) AS avg_value,
    unique_customers
FROM daily_order_metrics
ORDER BY date DESC
LIMIT 7;
"
echo ""

# 5. Customer Tiers
echo "5. CUSTOMER SPENDING TIERS"
echo "   Customer classification by spending"
echo "   ----------------------------------------"
$PSQL -c "
SELECT
    tier,
    COUNT(*) AS customer_count,
    ROUND(SUM(total_spent)::numeric, 2) AS tier_revenue
FROM customer_spending_tier
GROUP BY tier
ORDER BY
    CASE tier
        WHEN 'Gold' THEN 1
        WHEN 'Silver' THEN 2
        ELSE 3
    END;
"
echo ""

# 6. Recent Orders
echo "6. RECENT ORDERS (Last 5 per customer)"
echo "   Latest activity per customer"
echo "   ----------------------------------------"
$PSQL -c "
SELECT
    customer_name,
    order_id,
    ROUND(amount::numeric, 2) AS amount,
    status,
    created_at
FROM recent_orders
WHERE rank <= 5
ORDER BY customer_name, created_at DESC
LIMIT 15;
"
echo ""

echo "=========================================="
echo "  Use the queries above in RisingWave SQL:"
echo "  docker exec postgres psql -h risingwave -p 4566 -d dev"
echo "=========================================="
