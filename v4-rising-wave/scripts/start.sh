#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting PostgreSQL CDC to Iceberg Pipeline...${NC}"

# Check if docker compose is available
if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: docker compose not found${NC}"
    exit 1
fi

# Pull latest images
echo -e "${YELLOW}Pulling Docker images...${NC}"
docker compose pull

# Start services
echo -e "${YELLOW}Starting services...${NC}"
docker compose up -d

# Wait for services to be healthy
echo -e "${YELLOW}Waiting for services to be healthy...${NC}"

# Wait for PostgreSQL
echo -n "PostgreSQL..."
until docker exec postgres pg_isready -U postgres &> /dev/null; do
    echo -n "."
    sleep 2
done
echo -e " ${GREEN}OK${NC}"

# Wait for MinIO
echo -n "MinIO..."
until curl -sf http://localhost:9301/minio/health/live &> /dev/null; do
    echo -n "."
    sleep 2
done
echo -e " ${GREEN}OK${NC}"

# Wait for RisingWave
echo -n "RisingWave..."
until docker exec risingwave bash -c '> /dev/tcp/127.0.0.1/4566' &> /dev/null; do
    echo -n "."
    sleep 2
done
echo -e " ${GREEN}OK${NC}"

# Apply RisingWave CDC configuration
echo -e "${YELLOW}Applying RisingWave CDC configuration...${NC}"
sleep 5  # Give RisingWave extra time to fully initialize

# Wait for psql to be available in RisingWave
until docker exec risingwave psql -h localhost -p 4566 -d dev -c "SELECT 1" &> /dev/null; do
    echo -n "."
    sleep 2
done
echo ""

docker exec -i risingwave psql -h localhost -p 4566 -d dev < sql/02-risingwave-cdc.sql

# Apply streaming transformations
echo -e "${YELLOW}Creating streaming analytics transformations...${NC}"
docker exec -i risingwave psql -h localhost -p 4566 -d dev < sql/04-streaming-transforms.sql 2>/dev/null || echo "  (Note: Some transforms may already exist)"

# Apply Iceberg sinks
echo -e "${YELLOW}Creating Iceberg sinks for long-term storage...${NC}"
sleep 3  # Wait for Lakekeeper to be fully ready
docker exec -i risingwave psql -h localhost -p 4566 -d dev < sql/05-iceberg-sinks.sql 2>/dev/null || echo "  (Note: Some sinks may already exist)"

# Force a checkpoint to flush data
echo -e "${YELLOW}Flushing initial checkpoint...${NC}"
docker exec risingwave psql -h localhost -p 4566 -d dev -c "FLUSH;"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Pipeline started successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Services:"
echo "  - PostgreSQL:     localhost:5432"
echo "  - RisingWave SQL: localhost:4566"
echo "  - RisingWave UI:  http://localhost:5691"
echo "  - MinIO API:      http://localhost:9301"
echo "  - MinIO Console:  http://localhost:9400"
echo "  - Lakekeeper:     http://localhost:8181"
echo ""
echo "Data Flow:"
echo "  PostgreSQL CDC → RisingWave → JDBC Sink (real-time)"
echo "  PostgreSQL CDC → RisingWave → Iceberg Sink (MinIO)"
echo ""
echo "Commands:"
echo "  - Verify:   ./scripts/verify.sh"
echo "  - Analytics:./scripts/query-analytics.sh"
echo "  - Test:     ./scripts/insert-test-data.sh"
echo "  - Stop:     ./scripts/stop.sh"
echo ""