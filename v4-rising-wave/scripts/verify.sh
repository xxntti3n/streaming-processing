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
echo -e "${YELLOW}2. PostgreSQL - Customers:${NC}"
docker exec postgres psql -U postgres -d mydb -c "SELECT id, name, email FROM customers ORDER BY id;"
echo ""

echo -e "${YELLOW}3. PostgreSQL - Orders:${NC}"
docker exec postgres psql -U postgres -d mydb -c "SELECT id, customer_id, amount, status FROM orders ORDER BY id;"
echo ""

# Check RisingWave CDC streams
echo -e "${YELLOW}4. RisingWave CDC - Customers:${NC}"
docker exec risingwave psql -h localhost -p 4566 -d dev -c "SELECT id, name, email FROM customers_cdc ORDER BY id;" || echo -e "${RED}No data or table not ready${NC}"
echo ""

echo -e "${YELLOW}5. RisingWave CDC - Orders:${NC}"
docker exec risingwave psql -h localhost -p 4566 -d dev -c "SELECT id, customer_id, amount, status FROM orders_cdc ORDER BY id;" || echo -e "${RED}No data or table not ready${NC}"
echo ""

# Check Iceberg snapshots
echo -e "${YELLOW}6. Iceberg Snapshots - Customers:${NC}"
docker exec risingwave psql -h localhost -p 4566 -d dev -c "SELECT source_name, snapshot_id, record_count FROM rw_iceberg_snapshots WHERE source_name = 'customers_iceberg_sink';" || echo -e "${RED}No snapshots yet${NC}"
echo ""

echo -e "${YELLOW}7. Iceberg Snapshots - Orders:${NC}"
docker exec risingwave psql -h localhost -p 4566 -d dev -c "SELECT source_name, snapshot_id, record_count FROM rw_iceberg_snapshots WHERE source_name = 'orders_iceberg_sink';" || echo -e "${RED}No snapshots yet${NC}"
echo ""

# Check MinIO buckets
echo -e "${YELLOW}8. MinIO Buckets:${NC}"
docker exec mc sh -c "mc ls minio/" || echo -e "${RED}MinIO client not available${NC}"
echo ""

echo -e "${YELLOW}9. Iceberg Data in MinIO:${NC}"
docker exec mc sh -c "mc tree minio/iceberg-data/ --depth 2" || echo -e "${RED}No Iceberg data yet${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Verification Complete${NC}"
echo -e "${GREEN}========================================${NC}"
