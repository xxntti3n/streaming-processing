# PostgreSQL CDC to Iceberg via RisingWave Design

**Date:** 2025-03-22
**Author:** Claude
**Status:** Approved

## Overview

A streaming data pipeline that captures Change Data Capture (CDC) events from PostgreSQL and writes them to MinIO in Apache Iceberg format using RisingWave as the stream processing engine.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Docker Compose                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│   ┌──────────────┐         ┌─────────────────────────────────┐  │
│   │              │         │                                 │  │
│   │  PostgreSQL  │────────▶│    RisingWave Standalone       │  │
│   │   (source)   │   CDC   │  - PostgreSQL CDC Connector    │  │
│   │              │         │  - Stream Processing Engine    │  │
│   │  port: 5432  │         │  - Iceberg Sink                │  │
│   └──────────────┘         │                                 │  │
│                             │  port: 4566 (SQL), 5691 (UI)   │  │
│                             └────────────┬────────────────────┘  │
│                                          │                       │
│                                          ▼                       │
│                             ┌─────────────────────────────────┐  │
│                             │                                 │  │
│                             │           MinIO                 │  │
│                             │    (S3-compatible storage)     │  │
│                             │                                 │  │
│                             │  Bucket: iceberg-data/          │  │
│                             │  Format: Apache Iceberg         │  │
│                             │  port: 9301 (API), 9400 (UI)   │  │
│                             └─────────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Initial Snapshot:** RisingWave's PostgreSQL CDC connector performs an initial snapshot of existing table data
2. **Streaming CDC:** Changes are captured from PostgreSQL's WAL (Write-Ahead Log) via logical replication
3. **Stream Processing:** RisingWave processes the change stream in real-time
4. **Iceberg Sink:** Processed data is written to Iceberg tables in MinIO
5. **Metadata Storage:** Iceberg metadata is stored alongside data in MinIO (storage catalog mode)

## File Structure

```
v4-rising-wave/
├── docker-compose.yml              # Main orchestration file
├── .env                            # Environment variables for configuration
├── sql/
│   ├── 01-init-postgres.sql       # PostgreSQL source tables
│   ├── 02-risingwave-cdc.sql      # RisingWave CDC source and sink setup
│   └── 03-queries.sql              # Sample queries for verification
├── scripts/
│   ├── start.sh                    # Start the pipeline
│   ├── stop.sh                     # Stop and cleanup
│   ├── verify.sh                   # Verify data flow
│   └── insert-test-data.sh         # Generate test changes
└── README.md                       # Documentation
```

## Services

### PostgreSQL (Source)
- **Image:** `postgres:17-alpine`
- **Port:** 5432
- **Key Config:** `wal_level=logical` (required for CDC)
- **Resources:** 512MB memory
- **Database:** `mydb`
- **Example Tables:** `customers`, `orders`

### RisingWave Standalone
- **Image:** `risingwavelabs/risingwave:v2.7.1`
- **Ports:** 4566 (SQL), 5691 (Dashboard)
- **Components:** meta + compute + frontend + compactor (all-in-one)
- **Resources:** 4GB memory, 2 CPU cores
- **State Store:** MinIO (hummock+minio://...)
- **Key Parameters:**
  - `--parallelism 2` (reduced from default 8)
  - `--total-memory-bytes 4294967296` (4GB)

### MinIO
- **Image:** `quay.io/minio/minio:latest`
- **Ports:** 9301 (S3 API), 9400 (Console UI)
- **Resources:** 512MB memory
- **Buckets:**
  - `hummock001` (RisingWave state store)
  - `iceberg-data` (Iceberg sink output)
- **Credentials:** hummockadmin / hummockadmin

### MinIO Client (mc)
- **Purpose:** Init container to create buckets on startup
- **Action:** Creates `iceberg-data` bucket with public access

## Resource Allocation

| Service | Memory | CPU |
|---------|--------|-----|
| PostgreSQL | 512MB | 0.5 |
| RisingWave | 4GB | 2 |
| MinIO | 512MB | 0.5 |
| mc (init) | - | - |
| **Total** | ~6GB | ~3 |

## CDC + Iceberg Configuration

### PostgreSQL CDC Source
```sql
CREATE TABLE orders_cdc (
    order_id BIGINT PRIMARY KEY,
    customer_id BIGINT,
    order_date DATE,
    amount DECIMAL(10,2),
    status VARCHAR
) WITH (
    connector = 'postgres-cdc',
    hostname = 'postgres',
    port = '5432',
    username = 'postgres',
    password = 'postgres',
    database.name = 'mydb',
    schema.name = 'public',
    table.name = 'orders',
    slot.name = 'risingwave_cdc'
);
```

### Iceberg Sink
```sql
CREATE SINK orders_iceberg_sink
WITH (
    connector = 'iceberg',
    type = 'upsert',
    primary_key = 'order_id',
    warehouse.path = 's3a://iceberg-data',
    s3.endpoint = 'http://minio:9301',
    s3.access.key = 'hummockadmin',
    s3.secret.key = 'hummockadmin',
    s3.region = 'us-east-1',
    catalog.type = 'storage',
    catalog.name = 'demo',
    database.name = 'mydb',
    table.name = 'orders'
)
AS SELECT * FROM orders_cdc;
```

## Verification

### Manual Verification Steps
```bash
# 1. Check PostgreSQL source data
docker exec postgres psql -U postgres -d mydb -c "SELECT * FROM orders;"

# 2. Check RisingWave CDC stream
docker exec risingwave psql -h localhost -p 4566 -d dev -c "SELECT * FROM orders_cdc LIMIT 10;"

# 3. Check sink statistics
docker exec risingwave psql -h localhost -p 4566 -d dev -c "
    SELECT * FROM rw_iceberg_snapshots WHERE source_name = 'orders_iceberg_sink';
"

# 4. Verify Iceberg files in MinIO
mc ls minio/iceberg-data/mydb/orders/metadata/
mc ls minio/iceberg-data/mydb/orders/data/
```

### Health Checks
- **RisingWave Dashboard:** http://localhost:5691
- **MinIO Console:** http://localhost:9400 (hummockadmin/hummockadmin)
- **Services Status:** `docker compose ps`

## Error Handling

| Issue | Symptom | Solution |
|-------|---------|----------|
| PostgreSQL unavailable | CDC creation fails | Check PostgreSQL health, ensure `wal_level=logical` |
| Slot already exists | CDC creation fails | Drop slot: `SELECT pg_drop_replication_slot('slot_name')` |
| WAL buildup | Disk space growing | Ensure RisingWave is consuming; check slot activity |
| Missing data | Iceberg has fewer rows | Run `FLUSH;` to force checkpoint |

### CDC Position Tracking
- RisingWave stores CDC offset in its metadata store
- Automatic resume from last committed offset on restart
- No data loss on restart

## Schema Evolution

| Operation | Supported | Notes |
|-----------|-----------|-------|
| Add column | ✅ | RisingWave + Iceberg handle new columns |
| Drop column | ✅ | Metadata updated |
| Change column type | ⚠️ | Requires manual intervention |

## Security Considerations

This is a **development-focused** design with the following simplifications:

- Default credentials (no secrets management)
- No TLS/SSL encryption
- Public bucket access for MinIO

For **production deployment**, additional security measures would be required:
- Secrets management (HashiCorp Vault, AWS Secrets Manager)
- TLS for all connections
- Network policies and service mesh
- Authentication and authorization

## Success Criteria

1. ✅ PostgreSQL changes are captured via CDC
2. ✅ Initial snapshot is taken successfully
3. ✅ Ongoing changes stream in real-time
4. ✅ Data is written to MinIO in Iceberg format
5. ✅ Upsert mode handles inserts, updates, and deletes
6. ✅ Pipeline runs on 16GB development machine
7. ✅ Single `docker compose up` command to start
