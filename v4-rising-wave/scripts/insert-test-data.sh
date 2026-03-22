#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Inserting Test Data${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Insert new customer
echo -e "${YELLOW}1. Inserting new customer...${NC}"
docker exec postgres psql -U postgres -d mydb -c "
    INSERT INTO customers (name, email)
    VALUES ('Test User', 'test@example.com')
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
echo -e "${YELLOW}3. Updating an order...${NC}"
docker exec postgres psql -U postgres -d mydb -c "
    UPDATE orders
    SET status = 'completed', amount = amount * 1.1
    WHERE id = 1
    RETURNING id, customer_id, amount, status;
"
echo -e "${GREEN}✓ Done${NC}"
echo ""

# Wait for CDC to propagate
echo -e "${YELLOW}4. Waiting for CDC to propagate...${NC}"
sleep 5

# Flush RisingWave to ensure data is written to Iceberg
echo -e "${YELLOW}5. Flushing RisingWave...${NC}"
docker exec risingwave psql -h localhost -p 4566 -d dev -c "FLUSH;"
echo -e "${GREEN}✓ Done${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test data inserted!${NC}"
echo -e "${GREEN}Run './scripts/verify.sh' to see changes${NC}"
echo -e "${GREEN}========================================${NC}"
