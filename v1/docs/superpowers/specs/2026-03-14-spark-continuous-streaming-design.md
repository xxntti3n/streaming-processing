# Spark Continuous Streaming Architecture Design

**Date:** 2026-03-14
**Status:** Approved
**Author:** Claude + xxntti3n

## Overview

Restructure the streaming-processing v1 folder to replace Trino and Flink with a unified Spark architecture using continuous processing mode, with Lakekeeper as the Iceberg catalog and Kubernetes-first deployment.

## Motivation

- **Simplify stack:** Replace two compute engines (Flink + Trino) with one (Spark)
- **Lower latency:** Use Spark's continuous processing mode for sub-millisecond latency
- **Better catalog:** Centralize Iceberg metadata with Lakekeeper REST catalog
- **Kubernetes-native:** Deploy via Helm for consistent local and production environments

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Kubernetes Cluster                             │
│                                                                             │
│  MySQL → Kafka Connect → Kafka → Spark Streaming (Continuous) → Iceberg    │
│                                                           (Lakekeeper)     │
│                                                                   ↓         │
│                                                           Spark SQL         │
│                                                                   ↓         │
│                                                              Superset       │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Components

| Component | Role | Helm Chart |
|-----------|------|------------|
| **MySQL** | Source database with CDC | Bitnami MySQL |
| **Kafka** | CDC buffer and change log | Bitnami Kafka |
| **Kafka Connect** | CDC capture with Debezium | Bitnami Kafka (with Connect) |
| **Spark Operator** | Manages Spark applications on K8s | spark-operator |
| **Spark Streaming** | Continuous processing, writes to Iceberg | Custom SparkApplication |
| **Spark Thrift** | JDBC endpoint for Superset | Custom SparkApplication |
| **Lakekeeper** | Iceberg REST catalog | lakekeeper/lakekeeper |
| **MinIO** | S3-compatible storage | Bitnami MinIO |
| **Superset** | BI and visualization | Apache Superset |

## Data Flow

### 1. CDC Ingestion
```
MySQL Transaction → Binlog → Debezium → Kafka Topic
```

### 2. Streaming Processing
```
Kafka → Spark Continuous Reader → Transformations → Iceberg (via Lakekeeper)
```

### 3. Query
```
Superset → JDBC → Spark Thrift → Spark SQL → Iceberg → MinIO
```

## Continuous Processing Configuration

```scala
val df = spark.readStream
  .format("kafka")
  .option("kafka.bootstrap.servers", "kafka:9092")
  .option("subscribe", "mysql-cdc.appdb.orders")
  .load()
  .writeStream
  .format("iceberg")
  .option("checkpointLocation", "/checkpoints/orders")
  .trigger(Trigger.Continuous("1 second"))
  .start()
```

| Aspect | Value |
|--------|-------|
| **Latency** | ~1ms |
| **Trigger** | `Trigger.Continuous("1 second")` |
| **Guarantees** | At-least-once (exactly-once with Iceberg) |
| **Checkpoint** | Every 1 second |

## Resource Presets

| Preset | CPUs | Memory | Description |
|--------|------|--------|-------------|
| **barebones** | ~1.5 | ~2GB | CDC + Streaming only, no Superset |
| **minimal** | ~2.4 | ~4.5GB | Full stack, single executor |
| **default** | ~3.5 | ~6GB | Comfortable local dev |
| **performance** | ~6+ | ~10GB | Production-like testing |

### Resource Allocation (Minimal)

| Component | CPU | Memory |
|-----------|-----|--------|
| MySQL | 200m-500m | 256Mi-512Mi |
| Kafka | 300m-800m | 512Mi-1Gi |
| Zookeeper | 100m-200m | 256Mi-512Mi |
| Kafka Connect | 200m-500m | 384Mi-768Mi |
| Spark Driver | 500m-1 | 1Gi-2Gi |
| Spark Executor | 500m-1 | 1Gi-2Gi |
| Lakekeeper | 100m-300m | 256Mi-512Mi |
| MinIO | 200m-500m | 256Mi-512Mi |
| Superset | 300m-800m | 512Mi-1Gi |

## Folder Structure

```
v1/
├── helm/                          # Helm charts
│   ├── streaming-stack/           # Umbrella chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values-barebones.yaml
│   │   ├── values-minimal.yaml
│   │   ├── values-default.yaml
│   │   └── values-performance.yaml
│   ├── spark/                     # Spark Operator + jobs
│   ├── kafka/                     # Kafka + Zookeeper
│   ├── mysql/
│   ├── minio/
│   ├── lakekeeper/
│   └── superset/
├── spark-jobs/                    # Spark application code
│   └── streaming-processor/
├── scripts/                       # Utility scripts
│   ├── start.sh
│   ├── stop.sh
│   ├── check-capacity.sh
│   ├── verify-stack.sh
│   └── test-integration.sh
├── sql/                           # Database schemas
├── config/                        # Shared configuration
│   └── resources.yaml
├── tests/                         # E2E and integration tests
└── docs/                          # Documentation
```

## Error Handling

| Failure Mode | Handling |
|--------------|----------|
| MySQL down | Kafka Connect pauses, retries with backoff |
| Kafka broker down | Replication factor maintains availability |
| Spark executor crash | K8s restarts pod, recovery from checkpoint |
| Spark driver crash | Operator restarts, recovery from checkpoint |
| Lakekeeper down | Spark caches metadata, queues writes |
| MinIO down | Iceberg commits fail, Spark retries |

## Testing Strategy

1. **Unit Tests:** Spark transformations, SQL queries
2. **Integration Tests:** Component connectivity
3. **E2E Tests:** MySQL → Iceberg → Query path
4. **Continuous Mode Tests:** Latency SLA verification (< 5 seconds)

## Deployment

```bash
# Start with preset
./scripts/start.sh minimal

# Verify deployment
./scripts/verify-stack.sh

# Stop everything
./scripts/stop.sh
```

## Migration from v1

| v1 Component | v2 Replacement |
|--------------|----------------|
| Flink (jobmanager + taskmanager) | Spark Operator + Streaming Job |
| Trino | Spark SQL (Thrift Server) |
| Trino catalog | Lakekeeper REST Catalog |
| docker-compose | Helm charts |

## Open Questions

None at this time.

## References

- [Spark Structured Streaming](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html)
- [Spark Continuous Processing](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html#continuous-processing)
- [Lakekeeper](https://lakekeeper.io/)
- [Iceberg](https://iceberg.apache.org/)
