# Streaming Processing v1

Real-time streaming processing using Apache Spark with continuous processing mode.

## Architecture

```
MySQL CDC → Kafka → Spark Streaming → Iceberg → Spark SQL → BI Tools
            (Continuous Mode)         (Object Storage)
```

## Quick Start

```bash
# 1. Check system capacity
./scripts/check-capacity.sh

# 2. Deploy with preset (barebones, minimal, default, performance)
./scripts/start.sh minimal

# 3. Verify deployment
./scripts/verify-stack.sh

# 4. Run integration tests
./scripts/test-integration.sh
```

## Project Structure

```
v1/
├── config/              # Resource presets for different environments
├── docs/                # Architecture, deployment, troubleshooting guides
├── helm/
│   └── streaming-stack/ # Umbrella Helm chart (uses Bitnami charts)
├── scripts/             # Deployment and verification scripts
├── spark-jobs/          # Scala streaming processor code
└── tests/               # E2E and integration tests
```

## Components

| Component | Chart | Description |
|-----------|-------|-------------|
| MySQL | bitnami/mysql | Source database with CDC enabled |
| MinIO | bitnami/minio | S3-compatible object storage for Iceberg |
| Kafka | bitnami/kafka | Event streaming platform (Kraft mode) |

## Presets

- **barebones** - Absolute minimum resources for testing
- **minimal** - Resource-constrained, 2Gi storage
- **default** - Comfortable local development, 5Gi storage
- **performance** - Production-like, 20Gi storage, multiple replicas

## Documentation

- [Architecture](docs/architecture.md)
- [Deployment Guide](docs/deployment-guide.md)
- [Troubleshooting](docs/troubleshooting.md)
