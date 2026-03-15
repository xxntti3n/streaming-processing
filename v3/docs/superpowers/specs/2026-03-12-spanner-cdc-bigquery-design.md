# Spanner CDC to BigQuery - Design Specification

**Date:** 2026-03-12
**Author:** Design generated via brainstorming session
**Status:** Approved

---

## Overview

A real-time Change Data Capture (CDC) pipeline that streams changes from Cloud Spanner to BigQuery using Apache Flink SQL. The pipeline uses exactly-once processing semantics with checkpointing for fault tolerance.

**Goal:** Enable real-time Analytics/BI by synchronizing Spanner table changes to BigQuery with 5-10 second latency.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA FLOW                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Spanner Emulator                 Flink Cluster            BigQuery Emulator│
│  ┌───────────────┐               ┌──────────────┐          ┌──────────────┐ │
│  │  customers    │───Change─────▶│              │   SQL     │              │ │
│  │  products     │   Stream      │   Flink SQL  │───Pipe───▶│  customers   │ │
│  │  orders       │               │   Engine     │          │  products    │ │
│  └───────────────┘               │              │          │  orders      │ │
│                                   └──────────────┘          └──────────────┘ │
│                                          │                                  │
│                                   Checkpoints                                │
│                                    (MinIO)                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Component Overview

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Source** | Spanner Emulator | Change Streams API for CDC |
| **Processing** | Flink SQL | Stream transformation, joins, windowing |
| **Sink** | BigQuery Emulator | Streaming inserts, analytics queries |
| **Checkpoint** | MinIO | Exactly-once state backup |
| **Orchestration** | Kind + Helm | K8s deployment, minimal resources |
| **Monitoring** | Flink UI | Job health, checkpoints, metrics |

---

## Data Model

### Source Tables (Spanner)

```sql
-- Customers (dimension table)
CREATE TABLE customers (
    customer_id INT64,
    email STRING(100),
    name STRING(100),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
) PRIMARY KEY (customer_id);

-- Products (dimension table)
CREATE TABLE products (
    product_id INT64,
    sku STRING(50),
    name STRING(200),
    price NUMERIC,
    category STRING(50),
    created_at TIMESTAMP,
) PRIMARY KEY (product_id);

-- Orders (fact table - high change rate)
CREATE TABLE orders (
    order_id INT64,
    customer_id INT64,
    product_id INT64,
    quantity INT64,
    total_amount NUMERIC,
    order_status STRING(20),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
) PRIMARY KEY (order_id),
    INDEX (idx_orders_customer, customer_id),
    INDEX (idx_orders_product, product_id);
```

### Destination Tables (BigQuery)

Mirrored schema with additional metadata columns:
- All source columns
- `_spanner_commit_timestamp` - When the change was committed
- `_spanner_mod_type` - INSERT, UPDATE, or DELETE
- `_flink_ingest_timestamp` - When Flink processed the record

---

## Key Design Decisions

### 1. Change Streams vs. Polling

**Decision:** Use Spanner Change Streams API

**Rationale:**
- Managed CDC feature with guaranteed ordering
- No polling overhead or complexity
- Built-in retention window for replay
- Works in Spanner emulator

**Trade-off:** Requires Spanner feature configuration

### 2. Direct CDC vs. Kafka Intermediate

**Decision:** Direct Spanner → Flink → BigQuery (no intermediate Kafka)

**Rationale:**
- Simpler architecture (fewer moving parts)
- Lower latency (direct path)
- Matches existing v1/v2 patterns
- Single consumer use case (doesn't need Kafka's multi-consumer benefits)

**Trade-off:** Can't replay events without re-reading Spanner Change Streams

### 3. Exactly-Once Processing

**Strategy:**
- Flink checkpoints to MinIO every 5 seconds
- BigQuery insert idempotency via job ID + offset
- Spanner Change Streams retention: 1 hour (configurable)

**Benefits:**
- No duplicate records in BigQuery
- Recoverable from failures
- Accurate analytics

### 4. Type Mapping

| Spanner Type | BigQuery Type | Notes |
|--------------|---------------|-------|
| INT64 | INT64 | Direct mapping |
| STRING(N) | STRING | Length constraint handled by BigQuery |
| NUMERIC | NUMERIC | Same precision |
| TIMESTAMP | TIMESTAMP | UTC timezone assumed |
| ARRAY<T> | REPEATED T | Array types supported |

---

## Directory Structure

```
streaming-processing/v3/
├── helm-charts/
│   ├── kind-config.yaml           # Kind cluster (minimal resources)
│   ├── spanner-emulator/          # Spanner emulator chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       └── deployment.yaml
│   ├── bigquery-emulator/         # BigQuery emulator chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       └── deployment.yaml
│   ├── flink/                     # Flink deployment
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── jobmanager.yaml
│   │       └── taskmanager.yaml
│   └── minio/                     # Checkpoint storage
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           └── deployment.yaml
├── flink-jobs/
│   └── spanner-cdc/
│       ├── Dockerfile
│       ├── pom.xml
│       └── sql/
│           └── spanner-to-bigquery.sql
├── scripts/
│   ├── setup-cluster.sh           # Create Kind cluster
│   ├── deploy-all.sh              # Deploy all services
│   ├── setup-spanner.sh           # Initialize Spanner + data
│   ├── submit-job.sh              # Submit Flink SQL job
│   └── verify-pipeline.sh         # End-to-end test
├── infrastructure/
│   └── sql/
│       └── init.sql               # Sample e-commerce data
└── docs/
    └── superpowers/
        └── specs/
        └── 2026-03-12-spanner-cdc-bigquery-design.md
```

---

## Resource Profile (Minimal)

| Component | CPU | Memory | Replicas |
|-----------|-----|--------|----------|
| Flink JobManager | 0.5 | 1Gi | 1 |
| Flink TaskManager | 1.0 | 2Gi | 1 |
| Spanner Emulator | 0.5 | 512Mi | 1 |
| BigQuery Emulator | 0.5 | 512Mi | 1 |
| MinIO | 0.25 | 256Mi | 1 |
| **Total** | **~3 CPU** | **~4.5Gi** | - |

---

## Data Flow Details

### Change Streams Capture

```
Spanner Table Change → Change Stream → Partition → Flink Source
                       (commit_timestamp)
                       (record_sequence)
                       (mod_type: INSERT/UPDATE/DELETE)
```

### Flink SQL Processing Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│  Flink SQL Job                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. CREATE TABLE customers_source                              │
│     WITH ('connector' = 'spanner-cdc', ...)                     │
│                                                                 │
│  2. CREATE TABLE products_source                                │
│     WITH ('connector' = 'spanner-cdc', ...)                     │
│                                                                 │
│  3. CREATE TABLE orders_source                                  │
│     WITH ('connector' = 'spanner-cdc', ...)                     │
│                                                                 │
│  4. CREATE TABLE customers_sink                                 │
│     WITH ('connector' = 'bigquery', ...)                        │
│                                                                 │
│  5. INSERT INTO customers_sink SELECT * FROM customers_source;  │
│                                                                 │
│  6. (Repeat for products, orders)                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Checkpoint & Recovery

- MinIO stores Flink state backend
- On failure: resumes from last successful checkpoint
- Spanner Change Streams replay from saved offset
- BigQuery deduplication via insert IDs

---

## Monitoring

### Basic Monitoring (Implemented)

- **Flink Web UI** (port 8081)
  - Job status and health
  - Checkpoint statistics
  - Records sent/sec
  - Lag metrics

### Logging

- Flink JobManager: stdout/stderr → container logs
- Flink TaskManager: stdout/stderr → container logs
- Access via `kubectl logs`

---

## Success Criteria

1. **Functionality**
   - [ ] CDC captures all INSERT/UPDATE/DELETE from Spanner
   - [ ] Data appears in BigQuery within 5-10 seconds
   - [ ] Exactly-once semantics verified (no duplicates)

2. **Reliability**
   - [ ] Pipeline recovers from Flink restart
   - [ ] Pipeline recovers from Spanner restart
   - [ ] Pipeline recovers from BigQuery restart

3. **Observability**
   - [ ] Flink UI accessible
   - [ ] Checkpoints completing successfully
   - [ ] Metrics visible (records processed, lag)

---

## Future Enhancements (Out of Scope)

- Schema evolution support
- Multiple table joins in Flink SQL
- Aggregate tables (hourly/daily summaries)
- Production deployment to GCP
- Prometheus/Grafana integration

---

## References

- [Spanner Change Streams](https://cloud.google.com/spanner/docs/change-streams)
- [Flink BigQuery Connector](https://github.com/GoogleCloudDataproc/flink-bigquery-connector)
- [Spanner Emulator](https://github.com/GoogleCloudPlatform/cloud-spanner-emulator)
