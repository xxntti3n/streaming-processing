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