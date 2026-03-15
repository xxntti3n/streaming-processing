# Spanner to BigQuery CDC Pipeline - Flink Job

Real-time Change Data Capture pipeline from Google Cloud Spanner to BigQuery using Apache Flink.

## Architecture

```
Spanner (Emulator)          Flink Cluster           BigQuery (Emulator)
    │                          │                          │
    │ ──── CDC Changes ────────>│                          │
    │  (Change Streams API)     │                          │
    │                          │ ──── Upsert ─────────────>│
    │                          │  (INSERT/UPDATE/DELETE)   │
```

### Pipeline Flow

1. **SpannerChangeStreamSource** - Reads from Spanner
   - Phase 1: Snapshot - Reads all existing data from tables
   - Phase 2: Change Stream - Tails change stream for new changes
   - Checkpointed state for exactly-once semantics

2. **TableRouterFunction** - Adds target table metadata
   - Routes records to `test-project.ecommerce.{table_name}`

3. **BigQueryUpsertSink** - Writes to BigQuery
   - Handles INSERT, UPDATE, DELETE operations
   - HTTP client for emulator communication

## Project Structure

```
flink-jobs/spanner-cdc/
├── pom.xml                                    # Maven dependencies
├── src/main/
│   ├── java/com/example/streaming/
│   │   ├── SpannerCdcPipeline.java           # Main pipeline entry point
│   │   ├── model/
│   │   │   ├── Customer.java
│   │   │   ├── Product.java
│   │   │   └── Order.java
│   │   ├── source/
│   │   │   ├── ModType.java                  # INSERT/UPDATE/DELETE enum
│   │   │   ├── ChangeRecord.java             # CDC data model
│   │   │   ├── SourceState.java              # Checkpointed state
│   │   │   └── SpannerChangeStreamSource.java  # Spanner source
│   │   ├── routing/
│   │   │   └── TableRouterFunction.java      # Table routing logic
│   │   └── sink/
│   │       ├── BigQueryClient.java           # HTTP client for BQ
│   │       └── BigQueryUpsertSink.java       # Flink sink
│   └── resources/
│       ├── flink-conf.yaml                   # Flink configuration
│       └── log4j2.properties                 # Logging config

scripts/
├── deploy-all.sh                              # Deploy infrastructure
├── build-cdc-job.sh                           # Build JAR
├── submit-cdc-job.sh                          # Submit to Flink
├── verify-cdc-pipeline.sh                     # Health checks
├── insert-test-data.sh                        # Test data generator
└── setup-spanner-change-stream.sh             # DDL setup
```

## Quick Start

### 1. Prerequisites

- Kubernetes cluster (kind, minikube, or GKE)
- kubectl configured
- Maven 3.6+
- Docker (for local emulators)

### 2. Deploy Infrastructure

```bash
# Deploy Spanner, BigQuery, and Flink
./scripts/deploy-all.sh
```

This deploys:
- Spanner emulator at `spanner-emulator:9010`
- BigQuery emulator at `bigquery-emulator:9050`
- Flink 1.19.1 cluster (JobManager + TaskManager)

### 3. Setup Spanner Database

```bash
# Port forward to Spanner
kubectl port-forward svc/spanner-emulator 9010:9010 &

# Run the setup script to see DDL
./scripts/setup-spanner-change-stream.sh
```

Apply the DDL using gcloud CLI or spanner-cli to create:
- `customers`, `products`, `orders` tables
- `ecommerce_change_stream` change stream

### 4. Build and Submit Job

```bash
# Build the JAR
./scripts/build-cdc-job.sh

# Submit to Flink
./scripts/submit-cdc-job.sh
```

### 5. Monitor Pipeline

```bash
# Port forward to Flink UI
kubectl port-forward svc/flink-jobmanager 8081:8081

# Open http://localhost:8081
```

### 6. Verify Pipeline

```bash
./scripts/verify-cdc-pipeline.sh
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NAMESPACE` | `default` | Kubernetes namespace |
| `PARALLELISM` | `1` | Flink job parallelism |
| `FLINK_STATE_BACKEND` | `file:///tmp/flink-checkpoints` | Checkpoint storage |

### Flink Configuration

Edit `src/main/resources/flink-conf.yaml` to customize:
- Checkpoint interval
- State backend
- Memory settings

## Tables

### Customers
| Column | Type | Key |
|--------|------|-----|
| customer_id | INT64 | PK |
| email | STRING(100) | |
| name | STRING(100) | |
| created_at | TIMESTAMP | |
| updated_at | TIMESTAMP | |

### Products
| Column | Type | Key |
|--------|------|-----|
| product_id | INT64 | PK |
| sku | STRING(50) | |
| name | STRING(200) | |
| price | NUMERIC | |
| category | STRING(50) | |
| created_at | TIMESTAMP | |

### Orders
| Column | Type | Key |
|--------|------|-----|
| order_id | INT64 | PK |
| customer_id | INT64 | FK |
| product_id | INT64 | FK |
| quantity | INT64 | |
| total_amount | NUMERIC | |
| order_status | STRING(20) | |
| created_at | TIMESTAMP | |
| updated_at | TIMESTAMP | |

## Development

### Build Locally

```bash
cd flink-jobs/spanner-cdc
mvn clean package
```

### Run Tests

```bash
mvn test
```

### View Logs

```bash
# Flink JobManager logs
kubectl logs -l app=flink,component=jobmanager -f

# Flink TaskManager logs
kubectl logs -l app=flink,component=taskmanager -f
```

## Troubleshooting

### Job not starting
- Check JAR file exists: `ls -l flink-jobs/spanner-cdc/target/*.jar`
- Verify Flink cluster: `kubectl get pods -l app=flink`
- Check JobManager logs for errors

### No data flowing
- Verify Spanner change stream exists
- Check source is in CHANGE_STREAM phase (not SNAPSHOT)
- Verify BigQuery emulator is accessible
- Check Flink job metrics in UI

### Checkpoint failures
- Verify state backend directory is writable
- Check MinIO/S3 credentials if using distributed state
- Reduce checkpoint interval in flink-conf.yaml

## License

MIT
