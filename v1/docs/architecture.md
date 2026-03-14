# Architecture Overview

## Components

- MySQL - Source database with CDC
- Kafka - Event streaming with Debezium
- Spark - Stream processing and analytics
- Lakekeeper - Iceberg REST catalog
- MinIO - S3-compatible storage
- Superset - BI and visualization

## Data Flow

```
MySQL CDC → Kafka → Spark Streaming → Iceberg → Spark SQL → Superset
```
