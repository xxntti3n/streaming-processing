# PostgreSQL CDC to Iceberg via RisingWave Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a streaming data pipeline that captures PostgreSQL CDC events and writes them to MinIO in Apache Iceberg format using RisingWave, deployable via Docker Compose with minimal resources.

**Architecture:** PostgreSQL (source with logical replication) → RisingWave Standalone (CDC connector + stream processing + Iceberg sink) → MinIO (S3-compatible storage with Iceberg format). Single RisingWave container runs all components (meta, compute, frontend, compactor). Iceberg uses storage catalog mode (metadata stored alongside data in MinIO).

**Tech Stack:** Docker Compose, PostgreSQL 17, RisingWave v2.7.1, MinIO, Bash scripts, SQL

---

## File Structure

```
v4-rising-wave/
├── docker-compose.yml              # Main orchestration file
├── .env                            # Environment variables
├── sql/
│   ├── 01-init-postgres.sql       # PostgreSQL source tables
│   ├── 02-risingwave-cdc.sql      # RisingWave CDC source + sink
│   └── 03-queries.sql              # Verification queries
├── scripts/
│   ├── start.sh                    # Start the pipeline
│   ├── stop.sh                     # Stop and cleanup
│   ├── verify.sh                   # Verify data flow
│   └── insert-test-data.sh         # Generate test changes
└── README.md                       # Documentation
```

---

## Chunk 1: Project Foundation

### Task 1: Create README Documentation

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README with project overview**

```markdown
# PostgreSQL CDC to Iceberg via RisingWave

A streaming data pipeline that captures Change Data Capture (CDC) events from PostgreSQL and writes them to MinIO in Apache Iceberg format using RisingWave.

## Quick Start

```bash
# Start the pipeline
./scripts/start.sh

# Verify it's working
./scripts/verify.sh

# Insert test data
./scripts/insert-test-data.sh

# Stop the pipeline
./scripts/stop.sh
```

## Architecture

```
PostgreSQL → RisingWave → MinIO
   (CDC)        (process)    (Iceberg)
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| PostgreSQL | 5432 | Source database with CDC enabled |
| RisingWave | 4566 (SQL), 5691 (UI) | Stream processing engine |
| MinIO | 9301 (API), 9400 (Console) | S3-compatible storage |

## Resources

- Memory: ~6GB total
- Designed for 16GB development machines

## Documentation

- [Design Spec](docs/superpowers/specs/2025-03-22-postgres-cdc-risingwave-iceberg-design.md)
- [Implementation Plan](docs/superpowers/plans/2025-03-22-postgres-cdc-risingwave-iceberg.md)
```

- [ ] **Step 2: Commit README**

```bash
git add README.md
git commit -m "docs: add project README"
```

---

### Task 2: Create Environment Configuration

**Files:**
- Create: `.env`

- [ ] **Step 1: Create .env file with configuration variables**

```bash
# PostgreSQL Configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=mydb

# RisingWave Configuration
RW_IMAGE=risingwavelabs/risingwave:v2.7.1

# MinIO Configuration
MINIO_ROOT_USER=hummockadmin
MINIO_ROOT_PASSWORD=hummockadmin

# RisingWave Secret Key (for secrets management)
RW_SECRET_STORE_PRIVATE_KEY_HEX=0123456789abcdef0123456789abcdef
```

- [ ] **Step 2: Commit .env**

```bash
git add .env
git commit -m "chore: add environment configuration"
```

---

### Task 3: Create Docker Compose - Base Services

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: Create docker-compose.yml with PostgreSQL service**

```yaml
version: '3.8'

services:
  # PostgreSQL - Source Database with CDC enabled
  postgres:
    image: postgres:17-alpine
    container_name: postgres
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      POSTGRES_DB: ${POSTGRES_DB:-mydb}
    ports:
      - "5432:5432"
    command: ["postgres", "-c", "wal_level=logical", "-c", "max_replication_slots=10"]
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./sql/01-init-postgres.sql:/docker-entrypoint-initdb.d/01-init-postgres.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: always

  # MinIO - S3-compatible storage
  minio:
    image: quay.io/minio/minio:latest
    container_name: minio
    command:
      - server
      - "--address"
      - "0.0.0.0:9301"
      - "--console-address"
      - "0.0.0.0:9400"
      - /data
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-hummockadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:-hummockadmin}
    ports:
      - "9301:9301"
      - "9400:9400"
    volumes:
      - minio_data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9301/minio/health/live"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: always

  # MinIO Client - Initialize buckets
  mc:
    image: minio/mc
    container_name: mc
    depends_on:
      - minio
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-hummockadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:-hummockadmin}
    entrypoint: >
      /bin/sh -c "
      until (/usr/bin/mc alias set minio http://minio:9301 \${MINIO_ROOT_USER} \${MINIO_ROOT_PASSWORD}) do echo '...waiting...' && sleep 1; done;
      /usr/bin/mc mb minio/hummock001 --ignore-existing;
      /usr/bin/mc mb minio/iceberg-data --ignore-existing;
      /usr/bin/mc anonymous set download minio/iceberg-data;
      echo 'MinIO buckets initialized successfully';
      exit 0;
      "

volumes:
  postgres_data:
  minio_data:
```

- [ ] **Step 2: Test docker-compose.yml syntax**

Run: `docker compose config`
Expected: Valid YAML output with merged services

- [ ] **Step 3: Commit initial docker-compose**

```bash
git add docker-compose.yml
git commit -m "feat: add PostgreSQL and MinIO services to docker-compose"
```

---

## Chunk 2: SQL Schema and CDC Setup

### Task 4: Create PostgreSQL Source Tables

**Files:**
- Create: `sql/01-init-postgres.sql`

- [ ] **Step 1: Create SQL file with sample schema**

```sql
-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Customers table
CREATE TABLE IF NOT EXISTS customers (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name VARCHAR NOT NULL,
    email VARCHAR UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    customer_id BIGINT NOT NULL,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
);

-- Create indexes for better CDC performance
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_date ON orders(order_date);

-- Insert sample data
INSERT INTO customers (name, email) VALUES
    ('Alice Johnson', 'alice@example.com'),
    ('Bob Smith', 'bob@example.com'),
    ('Carol White', 'carol@example.com');

INSERT INTO orders (customer_id, order_date, amount, status) VALUES
    (1, '2025-01-15', 100.50, 'completed'),
    (2, '2025-01-16', 250.00, 'pending'),
    (1, '2025-01-17', 75.25, 'shipped');

-- Grant permissions
GRANT SELECT ON ALL TABLES IN SCHEMA public TO postgres;
GRANT REPLICATION CLIENT TO postgres;
```

- [ ] **Step 2: Create directory if needed and write file**

Run: `mkdir -p sql`
Expected: Directory created successfully

- [ ] **Step 3: Commit SQL schema**

```bash
git add sql/01-init-postgres.sql
git commit -m "feat: add PostgreSQL source tables schema"
```

---

### Task 5: Create RisingWave CDC and Iceberg Sink Configuration

**Files:**
- Create: `sql/02-risingwave-cdc.sql`

- [ ] **Step 1: Create RisingWave setup SQL**

```sql
-- ============================================================================
-- RisingWave CDC Source and Iceberg Sink Configuration
-- ============================================================================

-- Set CDC options for better behavior
SET sink_decouple = false;

-- ============================================================================
-- Secrets Management
-- ============================================================================

-- PostgreSQL password secret
CREATE SECRET IF NOT EXISTS postgres_pwd WITH (
    backend = 'meta'
) AS 'postgres';

-- MinIO access key secret
CREATE SECRET IF NOT EXISTS minio_access_key WITH (
    backend = 'meta'
) AS 'hummockadmin';

-- MinIO secret key secret
CREATE SECRET IF NOT EXISTS minio_secret_key WITH (
    backend = 'meta'
) AS 'hummockadmin';

-- ============================================================================
-- PostgreSQL CDC Sources
-- ============================================================================

-- Customers CDC Source
CREATE TABLE IF NOT EXISTS customers_cdc (
    id BIGINT PRIMARY KEY,
    name VARCHAR,
    email VARCHAR,
    created_at TIMESTAMP
) WITH (
    connector = 'postgres-cdc',
    hostname = 'postgres',
    port = '5432',
    username = 'postgres',
    password = SECRET postgres_pwd,
    database.name = 'mydb',
    schema.name = 'public',
    table.name = 'customers',
    slot.name = 'customers_cdc_slot'
);

-- Orders CDC Source
CREATE TABLE IF NOT EXISTS orders_cdc (
    id BIGINT PRIMARY KEY,
    customer_id BIGINT,
    order_date DATE,
    amount DECIMAL,
    status VARCHAR,
    created_at TIMESTAMP
) WITH (
    connector = 'postgres-cdc',
    hostname = 'postgres',
    port = '5432',
    username = 'postgres',
    password = SECRET postgres_pwd,
    database.name = 'mydb',
    schema.name = 'public',
    table.name = 'orders',
    slot.name = 'orders_cdc_slot'
);

-- ============================================================================
-- Iceberg Sinks
-- ============================================================================

-- Customers Iceberg Sink
CREATE SINK IF NOT EXISTS customers_iceberg_sink
WITH (
    connector = 'iceberg',
    type = 'upsert',
    primary_key = 'id',
    warehouse.path = 's3a://iceberg-data',
    s3.endpoint = 'http://minio:9301',
    s3.access.key = SECRET minio_access_key,
    s3.secret.key = SECRET minio_secret_key,
    s3.region = 'us-east-1',
    catalog.type = 'storage',
    catalog.name = 'demo',
    database.name = 'mydb',
    table.name = 'customers',
    create_table_if_not_exists = 'true'
)
AS SELECT * FROM customers_cdc;

-- Orders Iceberg Sink
CREATE SINK IF NOT EXISTS orders_iceberg_sink
WITH (
    connector = 'iceberg',
    type = 'upsert',
    primary_key = 'id',
    warehouse.path = 's3a://iceberg-data',
    s3.endpoint = 'http://minio:9301',
    s3.access.key = SECRET minio_access_key,
    s3.secret.key = SECRET minio_secret_key,
    s3.region = 'us-east-1',
    catalog.type = 'storage',
    catalog.name = 'demo',
    database.name = 'mydb',
    table.name = 'orders',
    create_table_if_not_exists = 'true'
)
AS SELECT * FROM orders_cdc;
```

- [ ] **Step 2: Commit CDC configuration**

```bash
git add sql/02-risingwave-cdc.sql
git commit -m "feat: add RisingWave CDC and Iceberg sink configuration"
```

---

### Task 6: Create Verification Queries

**Files:**
- Create: `sql/03-queries.sql`

- [ ] **Step 1: Create verification SQL queries**

```sql
-- ============================================================================
-- Verification Queries for PostgreSQL CDC to Iceberg Pipeline
-- ============================================================================

-- ============================================================================
-- 1. Check PostgreSQL Source Data
-- ============================================================================

\echo '=== PostgreSQL Source: Customers ==='
SELECT id, name, email FROM customers ORDER BY id;

\echo '=== PostgreSQL Source: Orders ==='
SELECT id, customer_id, order_date, amount, status FROM orders ORDER BY id;

-- ============================================================================
-- 2. Check RisingWave CDC Streams
-- ============================================================================

\echo '=== RisingWave CDC: Customers Stream ==='
SELECT id, name, email FROM customers_cdc ORDER BY id;

\echo '=== RisingWave CDC: Orders Stream ==='
SELECT id, customer_id, order_date, amount, status FROM orders_cdc ORDER BY id;

-- ============================================================================
-- 3. Check Iceberg Sink Statistics
-- ============================================================================

\echo '=== Iceberg Snapshots for Customers ==='
SELECT * FROM rw_iceberg_snapshots WHERE source_name = 'customers_iceberg_sink';

\echo '=== Iceberg Snapshots for Orders ==='
SELECT * FROM rw_iceberg_snapshots WHERE source_name = 'orders_iceberg_sink';

\echo '=== Iceberg Files for Customers ==='
SELECT * FROM rw_iceberg_files WHERE source_name = 'customers_iceberg_sink';

\echo '=== Iceberg Files for Orders ==='
SELECT * FROM rw_iceberg_files WHERE source_name = 'orders_iceberg_sink';

-- ============================================================================
-- 4. Row Count Verification
-- ============================================================================

\echo '=== Row Counts Comparison ==='
SELECT
    'customers_cdc' as source,
    COUNT(*) as row_count
FROM customers_cdc
UNION ALL
SELECT
    'orders_cdc' as source,
    COUNT(*) as row_count
FROM orders_cdc;
```

- [ ] **Step 2: Commit verification queries**

```bash
git add sql/03-queries.sql
git commit -m "feat: add verification queries"
```

---

## Chunk 3: Docker Compose - RisingWave Service

### Task 7: Add RisingWave Standalone Service

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Step 1: Add RisingWave service to docker-compose.yml**

After the `mc` service, add:

```yaml
  # RisingWave Standalone - Stream Processing Engine
  risingwave:
    image: ${RW_IMAGE:-risingwavelabs/risingwave:v2.7.1}
    container_name: risingwave
    command: "standalone --meta-opts=\" \
                    --listen-addr 0.0.0.0:5690 \
                    --advertise-addr 0.0.0.0:5690 \
                    --dashboard-host 0.0.0.0:5691 \
                    --backend sql \
                    --sql-endpoint postgres://postgres:postgres@postgres:5432/metadata \
                    --state-store hummock+minio://hummockadmin:hummockadmin@minio:9301/hummock001 \
                    --data-directory hummock_001 \
                    --config-path /risingwave.toml\" \
                 --compute-opts=\" \
                    --config-path /risingwave.toml \
                    --listen-addr 0.0.0.0:5688 \
                    --advertise-addr 0.0.0.0:5688 \
                    --async-stack-trace verbose \
                    --parallelism 2 \
                    --total-memory-bytes 4294967296 \
                    --role both \
                    --meta-address http://0.0.0.0:5690 \
                    --memory-manager-target-bytes 4294967296\" \
                 --frontend-opts=\" \
                   --config-path /risingwave.toml \
                   --listen-addr 0.0.0.0:4566 \
                   --advertise-addr 0.0.0.0:4566 \
                   --health-check-listener-addr 0.0.0.0:6786 \
                   --meta-addr http://0.0.0.0:5690 \
                   --frontend-total-memory-bytes=2147483648\" \
                 --compactor-opts=\" \
                   --listen-addr 0.0.0.0:6660 \
                   --advertise-addr 0.0.0.0:6660 \
                   --meta-address http://0.0.0.0:5690 \
                   --compactor-total-memory-bytes=1073741824\""
    ports:
      - "4566:4566"   # SQL frontend
      - "5690:5690"   # Meta
      - "5691:5691"   # Dashboard
      - "6786:6786"   # Health check
    depends_on:
      postgres:
        condition: service_healthy
      minio:
        condition: service_healthy
    environment:
      RUST_BACKTRACE: "1"
      ENABLE_TELEMETRY: "false"
      RW_SECRET_STORE_PRIVATE_KEY_HEX: ${RW_SECRET_STORE_PRIVATE_KEY_HEX:-0123456789abcdef0123456789abcdef}
    healthcheck:
      test:
        - CMD-SHELL
        - bash -c 'printf "GET / HTTP/1.1\n\n" > /dev/tcp/127.0.0.1/5688; exit $$?;'
        - bash -c '> /dev/tcp/127.0.0.1/4566; exit $$?;'
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: always
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
```

Also update the `volumes:` section to remove the unused volumes:

```yaml
volumes:
  postgres_data:
    driver: local
  minio_data:
    driver: local
```

- [ ] **Step 2: Test docker-compose configuration**

Run: `docker compose config`
Expected: Valid YAML with all services defined

- [ ] **Step 3: Commit RisingWave service**

```bash
git add docker-compose.yml
git commit -m "feat: add RisingWave standalone service"
```

---

## Chunk 4: Helper Scripts

### Task 8: Create Start Script

**Files:**
- Create: `scripts/start.sh`

- [ ] **Step 1: Create start script**

```bash
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
echo ""
echo "Commands:"
echo "  - Verify: ./scripts/verify.sh"
echo "  - Stop:   ./scripts/stop.sh"
echo ""
```

- [ ] **Step 2: Make script executable**

Run: `chmod +x scripts/start.sh`

- [ ] **Step 3: Commit start script**

```bash
git add scripts/start.sh
git commit -m "feat: add start script"
```

---

### Task 9: Create Stop Script

**Files:**
- Create: `scripts/stop.sh`

- [ ] **Step 1: Create stop script**

```bash
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
```

- [ ] **Step 2: Make script executable**

Run: `chmod +x scripts/stop.sh`

- [ ] **Step 3: Commit stop script**

```bash
git add scripts/stop.sh
git commit -m "feat: add stop script"
```

---

### Task 10: Create Verify Script

**Files:**
- Create: `scripts/verify.sh`

- [ ] **Step 1: Create verification script**

```bash
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
```

- [ ] **Step 2: Make script executable**

Run: `chmod +x scripts/verify.sh`

- [ ] **Step 3: Commit verify script**

```bash
git add scripts/verify.sh
git commit -m "feat: add verification script"
```

---

### Task 11: Create Test Data Script

**Files:**
- Create: `scripts/insert-test-data.sh`

- [ ] **Step 1: Create test data insertion script**

```bash
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
```

- [ ] **Step 2: Make script executable**

Run: `chmod +x scripts/insert-test-data.sh`

- [ ] **Step 3: Commit test data script**

```bash
git add scripts/insert-test-data.sh
git commit -m "feat: add test data insertion script"
```

---

## Chunk 5: Final Integration and Documentation

### Task 12: Create .gitignore

**Files:**
- Create: `.gitignore`

- [ ] **Step 1: Create .gitignore file**

```text
# Environment variables (keep template, ignore actual values if sensitive)
.env.local
.env.*.local

# Docker volumes
docker-volumes/

# OS files
.DS_Store
Thumbs.db

# IDE files
.idea/
.vscode/
*.swp
*.swo
*~

# Logs
*.log
logs/

# Temporary files
tmp/
temp/
```

- [ ] **Step 2: Commit .gitignore**

```bash
git add .gitignore
git commit -m "chore: add .gitignore"
```

---

### Task 13: Update README with Complete Documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README with complete documentation**

Replace the entire README.md content with:

```markdown
# PostgreSQL CDC to Iceberg via RisingWave

A streaming data pipeline that captures Change Data Capture (CDC) events from PostgreSQL and writes them to MinIO in Apache Iceberg format using RisingWave.

## Quick Start

```bash
# 1. Clone or navigate to the project
cd v4-rising-wave

# 2. Start the pipeline
./scripts/start.sh

# 3. Verify it's working
./scripts/verify.sh

# 4. Insert test data to see CDC in action
./scripts/insert-test-data.sh

# 5. Stop the pipeline when done
./scripts/stop.sh
```

## Architecture

```
┌──────────────┐         ┌─────────────────────┐         ┌─────────────┐
│  PostgreSQL  │────────▶│    RisingWave       │────────▶│    MinIO    │
│   (source)   │   CDC   │  (Stream Process)   │  Sink   │  (Iceberg)  │
│              │         │                     │         │             │
│  port: 5432  │         │  port: 4566 (SQL)   │         │  port: 9301 │
└──────────────┘         │  port: 5691 (UI)    │         │  port: 9400 │
                         └─────────────────────┘         └─────────────┘
```

## Features

- ✅ **PostgreSQL CDC**: Captures changes from PostgreSQL using logical replication
- ✅ **Initial Snapshot**: Automatically snapshots existing data
- ✅ **Real-time Streaming**: Changes propagate in seconds
- ✅ **Iceberg Format**: Data stored in Apache Iceberg format
- ✅ **Upsert Support**: Handles inserts, updates, and deletes
- ✅ **Minimal Resources**: Runs on ~6GB RAM (designed for 16GB dev machines)
- ✅ **Docker Compose**: Single command deployment

## Services

| Service | Port | Description | Access |
|---------|------|-------------|--------|
| PostgreSQL | 5432 | Source database with CDC enabled | `postgres://postgres:postgres@localhost:5432/mydb` |
| RisingWave SQL | 4566 | SQL interface for queries | `docker exec -it risingwave psql -h localhost -p 4566 -d dev` |
| RisingWave UI | 5691 | Web dashboard | http://localhost:5691 |
| MinIO API | 9301 | S3-compatible API | http://localhost:9301 |
| MinIO Console | 9400 | Web UI for MinIO | http://localhost:9400 (hummockadmin/hummockadmin) |

## Resource Requirements

| Service | Memory | CPU |
|---------|--------|-----|
| PostgreSQL | 512MB | 0.5 |
| RisingWave | 4GB | 2 |
| MinIO | 512MB | 0.5 |
| **Total** | ~6GB | ~3 |

Designed for development machines with 16GB RAM.

## Schema

### PostgreSQL Source Tables

**customers:**
- `id` (BIGINT, PK) - Auto-generated
- `name` (VARCHAR)
- `email` (VARCHAR)
- `created_at` (TIMESTAMP)

**orders:**
- `id` (BIGINT, PK) - Auto-generated
- `customer_id` (BIGINT, FK)
- `order_date` (DATE)
- `amount` (DECIMAL)
- `status` (VARCHAR)
- `created_at` (TIMESTAMP)

### Iceberg Tables

Data is written to `s3a://iceberg-data/mydb/{table_name}/` in Iceberg format.

## Scripts

| Script | Description |
|--------|-------------|
| `./scripts/start.sh` | Start all services and configure CDC |
| `./scripts/stop.sh` | Stop all services |
| `./scripts/verify.sh` | Verify data flow through the pipeline |
| `./scripts/insert-test-data.sh` | Insert test data to see CDC in action |

## Manual Queries

### Check PostgreSQL source data
```bash
docker exec postgres psql -U postgres -d mydb -c "SELECT * FROM orders;"
```

### Check RisingWave CDC stream
```bash
docker exec risingwave psql -h localhost -p 4566 -d dev -c "SELECT * FROM orders_cdc;"
```

### Check Iceberg snapshots
```bash
docker exec risingwave psql -h localhost -p 4566 -d dev -c "
  SELECT * FROM rw_iceberg_snapshots
  WHERE source_name = 'orders_iceberg_sink';
"
```

### List MinIO Iceberg files
```bash
docker exec mc sh -c "mc tree minio/iceberg-data/"
```

## Troubleshooting

### CDC slot already exists
```bash
docker exec postgres psql -U postgres -d mydb -c "
  SELECT pg_drop_replication_slot('customers_cdc_slot');
  SELECT pg_drop_replication_slot('orders_cdc_slot');
"
```

### Restart RisingWave
```bash
docker compose restart risingwave
```

### View RisingWave logs
```bash
docker compose logs -f risingwave
```

### Reinitialize from scratch
```bash
./scripts/stop.sh
docker compose down -v  # Removes volumes
./scripts/start.sh
```

## Documentation

- [Design Spec](docs/superpowers/specs/2025-03-22-postgres-cdc-risingwave-iceberg-design.md)
- [Implementation Plan](docs/superpowers/plans/2025-03-22-postgres-cdc-risingwave-iceberg.md)

## License

MIT
```

- [ ] **Step 2: Commit updated README**

```bash
git add README.md
git commit -m "docs: update README with complete documentation"
```

---

### Task 14: Final End-to-End Test

**Files:**
- None (testing)

- [ ] **Step 1: Start the pipeline**

Run: `./scripts/start.sh`
Expected: All services start successfully, CDC configuration applied

- [ ] **Step 2: Run initial verification**

Run: `./scripts/verify.sh`
Expected: See initial data from PostgreSQL in RisingWave

- [ ] **Step 3: Insert test data**

Run: `./scripts/insert-test-data.sh`
Expected: Test data inserted, flush completed

- [ ] **Step 4: Verify CDC propagation**

Run: `./scripts/verify.sh`
Expected: New data visible in RisingWave CDC streams

- [ ] **Step 5: Check Iceberg snapshots**

Run: `docker exec risingwave psql -h localhost -p 4566 -d dev -c "SELECT * FROM rw_iceberg_snapshots;"`
Expected: Snapshots exist for both customers and orders

- [ ] **Step 6: Verify MinIO data**

Run: `docker exec mc sh -c "mc tree minio/iceberg-data/"`
Expected: Iceberg metadata and data files present

- [ ] **Step 7: Stop the pipeline**

Run: `./scripts/stop.sh`
Expected: All containers stopped and removed

- [ ] **Step 8: Final commit**

```bash
git add -A
git commit -m "test: complete end-to-end testing verified"
```

---

## Completion Checklist

- [x] Docker Compose configuration with all services
- [x] PostgreSQL schema with sample tables
- [x] RisingWave CDC configuration
- [x] Iceberg sink configuration
- [x] Helper scripts (start, stop, verify, test data)
- [x] Complete documentation
- [x] End-to-end testing

## Next Steps

After implementation:

1. **Production Considerations:**
   - Use distributed RisingWave deployment
   - Add Iceberg REST Catalog
   - Implement secrets management
   - Add monitoring and alerting
   - Configure resource limits for production

2. **Extensions:**
   - Add more tables to CDC
   - Implement schema evolution strategy
   - Add data transformation in RisingWave
   - Set up additional sinks (materialized views, other databases)
