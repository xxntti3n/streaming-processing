# PostgreSQL CDC Pipeline via RisingWave

A streaming data pipeline that captures Change Data Capture (CDC) events from PostgreSQL and processes them through RisingWave with **both JDBC and Iceberg sink outputs**.

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
┌──────────────┐         ┌─────────────────────┐         ┌──────────────┐
│  PostgreSQL  │────────▶│    RisingWave       │────────▶│  PostgreSQL  │
│   (source)   │   CDC   │  (Stream Process)   │  Sink   │   (output)   │
│              │         │                     │  JDBC   │  *_sink tbls │
│  port: 5432  │         │  port: 4566 (SQL)   │         └──────────────┘
└──────────────┘         │  port: 5691 (UI)    │
                         └─────────────────────┘
                                 ▲
                                 │
                         ┌────────┴────────┐
                         │     MinIO       │
                         │ (Hummock Store) │
                         │  port: 9301     │
                         └─────────────────┘
                                 ▲
                                 │
                         ┌────────┴────────┐
                         │   Lakekeeper    │
                         │ (Iceberg REST)  │
                         │   port: 8181    │
                         └─────────────────┘
```

## Features

- ✅ **PostgreSQL CDC**: Captures changes from PostgreSQL using logical replication
- ✅ **Initial Snapshot**: Automatically snapshots existing data
- ✅ **Real-time Streaming**: Changes propagate in seconds
- ✅ **JDBC Sink**: CDC data written to PostgreSQL sink tables (near real-time)
- ✅ **Iceberg Sink**: CDC data written to Iceberg tables in MinIO (batch commits)
- ✅ **Lakekeeper Catalog**: Self-hosted Iceberg REST catalog for metadata management
- ✅ **Upsert Support**: Handles inserts, updates, and deletes
- ✅ **Minimal Resources**: Runs on ~8GB RAM (designed for 16GB dev machines)
- ✅ **Docker Compose**: Single command deployment

## Services

| Service | Port | Description | Access |
|---------|------|-------------|--------|
| PostgreSQL (source) | 5432 | Source database with CDC enabled | `postgres://postgres:postgres@localhost:5432/mydb` |
| RisingWave SQL | 4566 | SQL interface for queries | `docker exec postgres psql -h risingwave -p 4566 -d dev` |
| RisingWave UI | 5691 | Web dashboard | http://localhost:5691 |
| MinIO API | 9301 | S3-compatible storage | http://localhost:9301 |
| MinIO Console | 9400 | Web UI for MinIO | http://localhost:9400 (hummockadmin/hummockadmin) |
| Lakekeeper | 8181 | Iceberg REST Catalog | http://localhost:8181/catalog/ |
| Lakekeeper DB | 5433 | PostgreSQL for Lakekeeper metadata | `postgres://postgres:postgres@localhost:5433/postgres` |

## Resource Requirements

| Service | Memory | CPU |
|---------|--------|-----|
| PostgreSQL (source) | 512MB | 0.5 |
| RisingWave | 4GB | 2 |
| MinIO | 512MB | 0.5 |
| Lakekeeper + DB | 2GB | 1 |
| **Total** | ~8GB | ~4 |

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

### Sink Outputs

**JDBC Sink** (near real-time, sub-second latency):
- `customers_sink` - Same schema as source
- `orders_sink` - Same schema as source

**Iceberg Sink** (batch commits, ~30-60 seconds):
- `mydb.customers` - Stored in MinIO at `s3://hummock001/risingwave-iceberg/`
- `mydb.orders` - Stored in MinIO at `s3://hummock001/risingwave-iceberg/`

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
docker exec postgres psql -h risingwave -p 4566 -d dev -c "SELECT * FROM orders_cdc;"
```

### Check JDBC sink output
```bash
docker exec postgres psql -U postgres -d mydb -c "SELECT * FROM orders_sink;"
```

### Check Iceberg snapshots via Lakekeeper API
```bash
# Get warehouse ID
WAREHOUSE_ID=$(curl -s http://localhost:8181/management/v1/warehouse | jq -r '.warehouses[0]["warehouse-id"]')

# Check customers table snapshots
curl -s "http://localhost:8181/catalog/v1/${WAREHOUSE_ID}/namespaces/mydb/tables/customers" | jq '.metadata.snapshots'
```

### Test CDC with insert/update/delete
```bash
# Insert
docker exec postgres psql -U postgres -d mydb -c "INSERT INTO customers (name, email) VALUES ('Test', 'test@test.com') RETURNING *;"

# Wait 5 seconds, check JDBC sink (near real-time)
docker exec postgres psql -U postgres -d mydb -c "SELECT * FROM customers_sink WHERE name = 'Test';"

# Wait 60 seconds, check Iceberg (batch commit)
curl -s "http://localhost:8181/catalog/v1/${WAREHOUSE_ID}/namespaces/mydb/tables/customers" | jq '.metadata.snapshots[-1].summary'

# Update
docker exec postgres psql -U postgres -d mydb -c "UPDATE customers SET email = 'updated@test.com' WHERE name = 'Test';"
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

## Iceberg with Lakekeeper

This project uses **Lakekeeper**, a self-hosted Iceberg REST catalog, enabling RisingWave to write CDC data to Iceberg tables in MinIO.

### Key Features

- **Self-hosted**: No external services required
- **REST API**: Full Iceberg REST catalog implementation
- **MinIO Compatible**: Works with S3-compatible storage
- **Time Travel**: Snapshot-based for historical queries

### Creating New Iceberg Tables

1. Create namespace and table via Lakekeeper API:
```bash
WAREHOUSE_ID=$(curl -s http://localhost:8181/management/v1/warehouse | jq -r '.warehouses[0]["warehouse-id"]')

# Create namespace
curl -X POST "http://localhost:8181/catalog/v1/${WAREHOUSE_ID}/namespaces" \
  -H "Content-Type: application/json" \
  -d '{"namespace": ["mydb"]}'

# Create table (use timestamp not timestamptz)
curl -X POST "http://localhost:8181/catalog/v1/${WAREHOUSE_ID}/namespaces/mydb/tables" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my_table",
    "schema": {
      "type": "struct",
      "fields": [
        {"id": 1, "name": "id", "type": "long", "required": true},
        {"id": 2, "name": "data", "type": "string", "required": true}
      ]
    },
    "partition-spec": {"spec-id": 0, "fields": []}
  }'
```

2. Create Iceberg sink in RisingWave:
```sql
CREATE SINK my_table_iceberg_sink
FROM my_table_cdc
WITH (
    connector = 'iceberg',
    type = 'upsert',
    primary_key = 'id',
    warehouse.path = 'risingwave-warehouse',
    database.name = 'mydb',
    table.name = 'my_table',
    catalog.type = 'rest',
    catalog.uri = 'http://lakekeeper:8181/catalog/',
    s3.endpoint = 'http://minio:9301',
    s3.region = 'us-east-1',
    s3.access.key = 'hummockadmin',
    s3.secret.key = 'hummockadmin',
    s3.path.style.access = 'true'
);
```

## Documentation

- [Iceberg Research](docs/iceberg-research.md) - Investigation into RisingWave Iceberg support

## License

MIT
