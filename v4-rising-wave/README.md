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
