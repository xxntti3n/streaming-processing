#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Inserting Test Data - CDC Demo${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Insert new customer
echo -e "${YELLOW}1. Inserting new customer...${NC}"
docker exec postgres psql -U postgres -d mydb -c "
    INSERT INTO customers (name, email)
    VALUES ('Demo User', 'demo@example.com')
    RETURNING id, name, email;
"
echo -e "${GREEN}✓ Done${NC}"
echo ""

# Insert new orders
echo -e "${YELLOW}2. Inserting new orders...${NC}"
docker exec postgres psql -U postgres -d mydb -c "
    INSERT INTO orders (customer_id, amount, status)
    VALUES
        (1, 99.99, 'pending'),
        (2, 149.50, 'shipped'),
        (1, 29.99, 'completed')
    RETURNING id, customer_id, amount, status;
"
echo -e "${GREEN}✓ Done${NC}"
echo ""

# Update an existing order
echo -e "${YELLOW}3. Updating an existing order...${NC}"
docker exec postgres psql -U postgres -d mydb -c "
    UPDATE orders
    SET status = 'delivered', amount = amount * 1.1
    WHERE id = 1
    RETURNING id, customer_id, amount, status;
"
echo -e "${GREEN}✓ Done${NC}"
echo ""

# Wait for CDC to propagate
echo -e "${YELLOW}4. Waiting for CDC to propagate (5 seconds)...${NC}"
sleep 5

# Show CDC results
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}CDC Results${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}PostgreSQL Source (customers):${NC}"
docker exec postgres psql -U postgres -d mydb -c "SELECT id, name, email FROM customers WHERE name IN ('Demo User', 'Alice Johnson') ORDER BY id;"
echo ""

echo -e "${YELLOW}RisingWave CDC (customers_cdc):${NC}"
docker exec postgres psql -h risingwave -p 4566 -d dev -c "SELECT id, name, email FROM customers_cdc WHERE name IN ('Demo User', 'Alice Johnson') ORDER BY id;"
echo ""

echo -e "${YELLOW}JDBC Sink (customers_sink):${NC}"
docker exec postgres psql -U postgres -d mydb -c "SELECT id, name, email FROM customers_sink WHERE name IN ('Demo User', 'Alice Johnson') ORDER BY id;"
echo ""

echo -e "${YELLOW}PostgreSQL Source (orders - showing update):${NC}"
docker exec postgres psql -U postgres -d mydb -c "SELECT id, customer_id, amount, status FROM orders WHERE id = 1;"
echo ""

echo -e "${YELLOW}JDBC Sink (orders_sink - showing CDC captured update):${NC}"
docker exec postgres psql -U postgres -d mydb -c "SELECT id, customer_id, amount, status FROM orders_sink WHERE id = 1;"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CDC Demo Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
