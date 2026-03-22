#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Stopping PostgreSQL CDC to Iceberg Pipeline...${NC}"

# Stop and remove containers
docker compose down

# Optional: Remove volumes (commented out by default for safety)
# docker compose down -v

echo -e "${GREEN}Pipeline stopped.${NC}"
echo ""
echo "To start again: ./scripts/start.sh"
