# Streaming Processing v1

Real-time streaming processing using Apache Spark with continuous processing mode.

## Quick Start

```bash
./scripts/check-capacity.sh
./scripts/start.sh minimal
./scripts/verify-stack.sh
```

## Architecture

```
MySQL CDC → Kafka → Spark Streaming → Iceberg → Spark SQL → Superset
            (Continuous Mode)         (Lakekeeper)
```

## Documentation

- [Architecture](docs/architecture.md)
- [Deployment Guide](docs/deployment-guide.md)
- [Troubleshooting](docs/troubleshooting.md)
