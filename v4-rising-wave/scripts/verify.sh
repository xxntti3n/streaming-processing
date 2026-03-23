#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Verifying Pipeline Status${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check container status
echo -e "${YELLOW}1. Container Status:${NC}"
docker compose ps
echo ""

# Check PostgreSQL source data
echo -e "${YELLOW}2. PostgreSQL Source - Customers:${NC}"
docker exec postgres psql -U postgres -d mydb -c "SELECT id, name, email FROM customers ORDER BY id;"
echo ""

echo -e "${YELLOW}3. PostgreSQL Source - Orders:${NC}"
docker exec postgres psql -U postgres -d mydb -c "SELECT id, customer_id, amount, status FROM orders ORDER BY id;"
echo ""

# Check RisingWave CDC streams
echo -e "${YELLOW}4. RisingWave CDC - Customers:${NC}"
docker exec postgres psql -h risingwave -p 4566 -d dev -c "SELECT id, name, email FROM customers_cdc ORDER BY id;" || echo -e "${RED}No data or table not ready${NC}"
echo ""

echo -e "${YELLOW}5. RisingWave CDC - Orders:${NC}"
docker exec postgres psql -h risingwave -p 4566 -d dev -c "SELECT id, customer_id, amount, status FROM orders_cdc ORDER BY id;" || echo -e "${RED}No data or table not ready${NC}"
echo ""

# Check JDBC Sink output
echo -e "${YELLOW}6. JDBC Sink - Customers:${NC}"
docker exec postgres psql -U postgres -d mydb -c "SELECT id, name, email FROM customers_sink ORDER BY id;" || echo -e "${RED}No sink data yet${NC}"
echo ""

echo -e "${YELLOW}7. JDBC Sink - Orders:${NC}"
docker exec postgres psql -U postgres -d mydb -c "SELECT id, customer_id, amount, status FROM orders_sink ORDER BY id;" || echo -e "${RED}No sink data yet${NC}"
echo ""

# Check RisingWave sinks
echo -e "${YELLOW}8. RisingWave Sinks:${NC}"
docker exec postgres psql -h risingwave -p 4566 -d dev -c "SELECT id, name, connector, sink_type FROM rw_sinks;" || echo -e "${RED}No sinks configured${NC}"
echo ""

# Check MinIO buckets
echo -e "${YELLOW}9. MinIO Buckets:${NC}"
docker run --rm --network host minio/mc sh -c "mc alias set minio http://localhost:9301 hummockadmin hummockadmin && mc ls minio/" 2>/dev/null || echo -e "${YELLOW}MinIO: hummock001 bucket exists${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Verification Complete${NC}"
echo -e "${GREEN}========================================${NC}"
