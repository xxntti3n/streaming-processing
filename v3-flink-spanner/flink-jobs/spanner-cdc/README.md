# Spanner CDC to Iceberg Pipeline

Real-time Change Data Capture (CDC) pipeline streaming from Google Cloud Spanner to Apache Iceberg using Apache Flink.

## Project Overview

This project implements a production-ready CDC pipeline that captures change events from Spanner and replicates them to Apache Iceberg tables in near real-time. The pipeline uses Apache Flink for stream processing with exactly-once semantics and automatic checkpoint-based recovery. Iceberg tables are stored on MinIO (S3-compatible storage) with a REST catalog for metadata management.

### Key Features

- **Change Stream Integration**: Leverages Spanner Change Streams API for efficient CDC
- **Two-Phase Processing**: Snapshot phase for historical data, change stream for ongoing changes
- **Exactly-Once Semantics**: Checkpointed state ensures no data loss or duplication
- **Upsert Logic**: Handles INSERT, UPDATE, and DELETE operations in Iceberg tables
- **Table Routing**: Dynamically routes changes to appropriate Iceberg tables
- **Data Lake Architecture**: Uses Iceberg on MinIO for open format data storage
- **Emulator Support**: Works with local Spanner emulator for development

### Use Cases

- Real-time analytics dashboards
- Data warehousing and data lake synchronization
- Multi-region data replication
- Audit logging and change tracking

## Architecture

```
Spanner (Emulator)        Flink Cluster          Iceberg on MinIO
     |                         |                        |
     |--CDC Changes--> [Source]-->[Router]-->[Sink] --|
                          |          |          |
                       Checkpoint   Target     Upsert
                          State      Table     Logic
                                          |
                                    REST Catalog
```

### Pipeline Components

#### 1. SpannerChangeStreamSource
- **Phase 1 - Snapshot**: Reads all existing data from source tables
- **Phase 2 - Change Stream**: Tails Spanner change stream for new changes
- Maintains checkpointed state for exactly-once processing
- Handles connection failures and automatic retries

#### 2. TableRouterFunction
- Adds Iceberg target table metadata to each change record
- Routes to `ecommerce.{table_name}` in the Iceberg catalog
- Supports dynamic table discovery

#### 3. IcebergUpsertSink
- Writes changes to Iceberg tables using Flink Iceberg sink
- Implements upsert logic (INSERT/UPDATE/DELETE) via Iceberg's row-level operations
- Integrates with MinIO for data storage and REST catalog for metadata
- Batch writes for optimal performance with Iceberg's append-heavy format

### Data Flow

```
Spanner Change Event
    |
    v
ChangeRecord (ModType, Data, PartitionToken, Timestamp)
    |
    v
TableRouterFunction (adds target table metadata)
    |
    v
IcebergUpsertSink (writes via Flink Iceberg sink)
    |
    v
Iceberg Table on MinIO (updated via REST Catalog)
```

## Prerequisites

### Required Tools

- **Docker**: For running emulators locally
  ```bash
  docker --version  # Docker 20.10+
  ```

- **kubectl**: For Kubernetes cluster interaction
  ```bash
  kubectl version --client  # v1.24+
  ```

- **Maven**: For building the Flink job JAR
  ```bash
  mvn --version  # Maven 3.6+
  ```

- **Java Development Kit**: For compilation and execution
  ```bash
  java -version  # Java 11+
  ```

- **Kubernetes Cluster**: kind, minikube, or GKE
  ```bash
  kubectl cluster-info
  ```

### Optional Tools

- **gcloud CLI**: For Spanner DDL operations
- **spanner-cli**: Interactive Spanner terminal
- **helm**: For Helm-based deployments (if using Helm charts)

## Local Development Setup

### 1. Clone the Repository

```bash
cd /path/to/streaming-processing/v3
git checkout -b your-feature-branch
```

### 2. Start Kubernetes Cluster

If using kind:
```bash
kind create cluster --name spanner-cdc
```

If using minikube:
```bash
minikube start --driver=docker
```

### 3. Deploy Infrastructure

Use the provided deployment script:
```bash
./scripts/deploy-all.sh
```

This deploys:
- Spanner emulator at `spanner-emulator:9010`
- MinIO for S3-compatible storage at `minio:9000`
- Iceberg REST catalog at `iceberg-rest-catalog:8181`
- Flink 1.19.1 cluster (JobManager + TaskManager)

All components are deployed to the `default` namespace.

### 4. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n default

# Expected output:
# NAME                                 READY   STATUS    RESTARTS   AGE
# spanner-emulator-xxxxx               1/1     Running   0          2m
# minio-xxxxx                          1/1     Running   0          2m
# iceberg-rest-catalog-xxxxx           1/1     Running   0          2m
# flink-jobmanager-xxxxx               1/1     Running   0          2m
# flink-taskmanager-xxxxx              1/1     Running   0          2m
```

### 5. Setup Spanner Database

```bash
./scripts/setup-spanner-change-stream.sh
```

This creates:
- `customers` table
- `products` table
- `orders` table
- `ecommerce_change_stream` change stream

#### Manual DDL Setup

If you prefer to apply DDL manually:

```bash
# Port forward to Spanner
kubectl port-forward svc/spanner-emulator 9010:9010 &

# Set emulator environment
export SPANNER_EMULATOR_HOST=localhost:9010

# Apply DDL via gcloud
gcloud spanner databases ddl update ecommerce \
  --instance=test-instance \
  --project=test-project \
  --ddl="$(cat <<EOF
CREATE TABLE customers (
    customer_id INT64 NOT NULL,
    email STRING(100),
    name STRING(100),
    created_at TIMESTAMP,
    updated_at TIMESTAMP
) PRIMARY KEY (customer_id);

CREATE TABLE products (
    product_id INT64 NOT NULL,
    sku STRING(50),
    name STRING(200),
    price NUMERIC,
    category STRING(50),
    created_at TIMESTAMP
) PRIMARY KEY (product_id);

CREATE TABLE orders (
    order_id INT64 NOT NULL,
    customer_id INT64 NOT NULL,
    product_id INT64 NOT NULL,
    quantity INT64 NOT NULL,
    total_amount NUMERIC,
    order_status STRING(20),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
) PRIMARY KEY (order_id);

CREATE CHANGE STREAM ecommerce_change_stream
FOR customers, products, orders
OPTIONS (
    retention_period = '1h',
    capture_value_change_type = 'NEW_ROW_AND_OLD_ROW'
);
EOF
)"
```

## Building the JAR

### Build Using Script

```bash
./scripts/build-cdc-job.sh
```

### Build Manually

```bash
cd flink-jobs/spanner-cdc
mvn clean package -DskipTests
```

### Verify Build

```bash
ls -lh flink-jobs/spanner-cdc/target/spanner-cdc-bigquery-1.0-SNAPSHOT.jar
```

Expected output: JAR file of ~80-100 MB containing all dependencies.

## Deploying to Kubernetes

### Option 1: Using Scripts

```bash
# 1. Build the JAR
./scripts/build-cdc-job.sh

# 2. Submit to Flink
./scripts/submit-cdc-job.sh

# 3. Verify deployment
./scripts/verify-cdc-pipeline.sh
```

### Option 2: Manual Deployment

```bash
# Set namespace
export NAMESPACE=default

# Build JAR
cd flink-jobs/spanner-cdc
mvn clean package -DskipTests
cd ../..

# Copy JAR to JobManager
JM_POD=$(kubectl get pod -l app=flink,component=jobmanager -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
kubectl cp flink-jobs/spanner-cdc/target/spanner-cdc-bigquery-1.0-SNAPSHOT.jar $NAMESPACE/$JM_POD:/tmp/

# Submit job
kubectl exec $JM_POD -n $NAMESPACE -- /opt/flink/bin/flink run \
  -c com.example.streaming.SpannerCdcPipeline \
  -d \
  /tmp/spanner-cdc-bigquery-1.0-SNAPSHOT.jar
```

### Monitor Job Submission

```bash
# Port forward to Flink UI
kubectl port-forward svc/flink-jobmanager 8081:8081

# Open http://localhost:8081 in browser
# Navigate to "Running Jobs" to see the pipeline
```

## Verifying the Pipeline

### 1. Run Health Checks

```bash
./scripts/verify-cdc-pipeline.sh
```

Expected output:
```
==================================================
Verifying Spanner CDC Pipeline
==================================================

Checking Infrastructure...
--------------------------
✓ Service 'spanner-emulator' exists
✓ Service 'flink-jobmanager' exists
✓ Service 'flink-taskmanager' exists
✓ Service 'minio' exists
✓ Service 'iceberg-rest-catalog' exists

Checking Pods...
--------------------------
✓ Pod with label 'app=spanner-emulator' is running
✓ Pod with label 'app=minio' is running
✓ Pod with label 'app=iceberg-rest-catalog' is running
✓ Pod with label 'app=flink,component=jobmanager' is running
✓ Pod with label 'app=flink,component=taskmanager' is running

Checking Flink Jobs...
--------------------------
✓ Flink Web UI is accessible
✓ CDC job is running

==================================================
Verification Complete
==================================================
Passed: 10
Failed: 0

✓ All checks passed!
```

### 2. Insert Test Data

```bash
./scripts/insert-test-data.sh
```

This inserts:
- 5 customers
- 5 products
- 3 orders

### 3. Verify Data Flow

```bash
# Check Flink job metrics
kubectl port-forward svc/flink-jobmanager 8081:8081
# Open http://localhost:8081
# Check: numRecordsIn, numRecordsOut, numSucceededCheckpoints

# Check Iceberg catalog for tables
kubectl exec -it deployment/iceberg-rest-catalog -- \
  curl -s http://localhost:8181/v1/namespaces/ecommerce/tables

# Query Iceberg tables via spark-sql or trino
# Example: Check data in MinIO via mc (MinIO Client)
kubectl exec -it deployment/minio -- mc ls local/warehouse/ecommerce/
```

### 4. View Logs

```bash
# Flink JobManager logs
kubectl logs -l app=flink,component=jobmanager -f

# Flink TaskManager logs
kubectl logs -l app=flink,component=taskmanager -f

# Spanner emulator logs
kubectl logs -l app=spanner-emulator -f

# MinIO logs
kubectl logs -l app=minio -f

# Iceberg REST catalog logs
kubectl logs -l app=iceberg-rest-catalog -f
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SPANNER_EMULATOR_HOST` | `spanner-emulator:9010` | Spanner emulator host:port |
| `ICEBERG_CATALOG_URI` | `http://iceberg-rest-catalog:8181` | Iceberg REST catalog endpoint |
| `ICEBERG_WAREHOUSE` | `s3a://warehouse/` | MinIO S3 path for Iceberg data |
| `MINIO_ENDPOINT` | `http://minio:9000` | MinIO endpoint for S3 storage |
| `FLINK_STATE_BACKEND` | `file:///tmp/flink-checkpoints` | Checkpoint storage location |
| `FLINK_CHECKPOINT_INTERVAL_MS` | `1000` | Checkpoint interval in milliseconds (lower = lower latency, higher = less overhead) |
| `NAMESPACE` | `default` | Kubernetes namespace |
| `PARALLELISM` | `1` | Flink job parallelism |
| `PROJECT_ID` | `test-project` | Project ID for Iceberg namespace |
| `INSTANCE_ID` | `test-instance` | Spanner instance ID |
| `DATABASE_ID` | `ecommerce` | Spanner database ID |

### Flink Configuration

Edit `src/main/resources/flink-conf.yaml`:

```yaml
# State backend configuration
state.backend: jobmanager
state.checkpoints.dir: file:///tmp/flink-checkpoints

# Checkpointing settings
execution.checkpointing.interval: 1000         # 1 second (was 5000)
execution.checkpointing.mode: exactly_once
execution.checkpointing.timeout: 30000         # 30 seconds (was 60000)
execution.checkpointing.min-pause: 500         # 500ms (was 10000)
execution.checkpointing.max-concurrent-checkpoints: 1

# Restart strategy
restart-strategy: fixed-delay
restart-strategy.fixed-delay.attempts: 3
restart-strategy.fixed-delay.delay: 10000     # 10 seconds
```

### Advanced Configuration

For production deployments, consider:

- **Distributed State Backend**: Use RocksDB with S3/MinIO
- **Checkpoint Retention**: Configure checkpoint retention policy
- **Metrics**: Enable Prometheus metrics export
- **Resource Allocation**: Adjust TaskManager memory and slots

## Schema Reference

### Customers Table

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| customer_id | INT64 | PK | Customer identifier |
| email | STRING(100) | | Customer email |
| name | STRING(100) | | Customer name |
| created_at | TIMESTAMP | | Creation timestamp |
| updated_at | TIMESTAMP | | Last update timestamp |

### Products Table

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| product_id | INT64 | PK | Product identifier |
| sku | STRING(50) | | Stock keeping unit |
| name | STRING(200) | | Product name |
| price | NUMERIC | | Product price |
| category | STRING(50) | | Product category |
| created_at | TIMESTAMP | | Creation timestamp |

### Orders Table

| Column | Type | Key | Description |
|--------|------|-----|-------------|
| order_id | INT64 | PK | Order identifier |
| customer_id | INT64 | FK | Customer reference |
| product_id | INT64 | FK | Product reference |
| quantity | INT64 | | Order quantity |
| total_amount | NUMERIC | | Order total |
| order_status | STRING(20) | | Order status |
| created_at | TIMESTAMP | | Creation timestamp |
| updated_at | TIMESTAMP | | Last update timestamp |

## Troubleshooting

### Job Not Starting

**Symptoms**: Flink job fails to start or shows "FAILED" status

**Solutions**:
1. Verify JAR file exists
   ```bash
   ls -lh flink-jobs/spanner-cdc/target/*.jar
   ```

2. Check Flink cluster health
   ```bash
   kubectl get pods -l app=flink
   kubectl logs -l app=flink,component=jobmanager
   ```

3. Verify Java version compatibility
   ```bash
   kubectl exec deployment/flink-jobmanager -- java -version
   ```

4. Check for class conflicts
   ```bash
   kubectl logs -l app=flink,component=jobmanager | grep -i "class.*not.*found"
   ```

### No Data Flowing

**Symptoms**: Job is running but no records are processed

**Solutions**:
1. Verify Spanner change stream exists
   ```bash
   export SPANNER_EMULATOR_HOST=localhost:9010
   gcloud spanner change-streams list \
     --instance=test-instance \
     --database=ecommerce \
     --project=test-project
   ```

2. Check source phase (should be CHANGE_STREAM, not SNAPSHOT)
   ```bash
   kubectl logs -l app=flink,component=taskmanager | grep "Phase:"
   ```

3. Verify Iceberg catalog is accessible
   ```bash
   kubectl exec deployment/iceberg-rest-catalog -- \
     curl -s http://localhost:8181/v1/config
   ```

4. Verify MinIO storage is accessible
   ```bash
   kubectl exec deployment/minio -- mc ls local/
   ```

4. Check Flink job metrics
   ```bash
   # Port forward to UI
   kubectl port-forward svc/flink-jobmanager 8081:8081
   # Check: numRecordsIn, numRecordsOut
   ```

5. Verify Spanner has data
   ```bash
   gcloud spanner rows scan \
     --instance=test-instance \
     --database=ecommerce \
     --table=customers \
     --project=test-project
   ```

### Checkpoint Failures

**Symptoms**: Checkpoints are failing or not completing

**Solutions**:
1. Verify state backend directory is writable
   ```bash
   kubectl exec deployment/flink-jobmanager -- \
     ls -la /tmp/flink-checkpoints
   ```

2. Check checkpoint interval settings
   ```yaml
   # In flink-conf.yaml, ensure:
   execution.checkpointing.min-pause: 10000  # Allow time between checkpoints
   ```

3. Verify sufficient memory
   ```bash
   kubectl top pods -l app=flink
   ```

4. Check for timeout errors
   ```bash
   kubectl logs -l app=flink,component=taskmanager | grep -i "checkpoint.*timeout"
   ```

5. Reduce checkpoint interval if needed
   ```yaml
   execution.checkpointing.interval: 10000  # Increase to 10 seconds
   ```

### Performance Degradation

**Symptoms**: High CPU usage, checkpoint failures, backpressure

**Solutions**:

1. Increase checkpoint interval via environment variable
   ```bash
   export FLINK_CHECKPOINT_INTERVAL_MS=3000  # Back to 3 seconds
   ./scripts/submit-cdc-job.sh
   ```

2. Or revert to original 5-second interval
   ```bash
   export FLINK_CHECKPOINT_INTERVAL_MS=5000
   ./scripts/submit-cdc-job.sh
   ```

3. Check checkpoint duration in Flink UI
   - If checkpoint duration > interval, increase interval
   - Rule of thumb: checkpoint duration should be < 50% of interval

4. Monitor for checkpoint storms
   ```bash
   # Check checkpoint frequency
   kubectl logs -l app=flink,component=taskmanager | grep -i "completed checkpoint"
   ```

### Connection Issues

**Symptoms**: Cannot connect to Spanner, MinIO, or Iceberg catalog

**Solutions**:
1. Verify services are running
   ```bash
   kubectl get svc | grep -E "spanner|minio|iceberg"
   ```

2. Check service endpoints
   ```bash
   kubectl get svc spanner-emulator -o yaml
   kubectl get svc minio -o yaml
   kubectl get svc iceberg-rest-catalog -o yaml
   ```

3. Test connectivity from Flink pods
   ```bash
   kubectl exec deployment/flink-taskmanager -- \
     curl -v spanner-emulator:9010

   kubectl exec deployment/flink-taskmanager -- \
     curl -v http://minio:9000

   kubectl exec deployment/flink-taskmanager -- \
     curl -v http://iceberg-rest-catalog:8181
   ```

4. Check network policies
   ```bash
   kubectl get networkpolicy
   ```

### Memory Issues

**Symptoms**: OutOfMemoryError, pods being OOMKilled

**Solutions**:
1. Increase TaskManager memory
   ```yaml
   # In Flink deployment
   resources:
     limits:
       memory: "2Gi"
     requests:
       memory: "1Gi"
   ```

2. Adjust Flink memory settings
   ```yaml
   env:
   - name: FLINK_PROPERTIES
     value: |
       jobmanager.memory.process.size: 1600m
       taskmanager.memory.process.size: 1728m
   ```

3. Reduce parallelism
   ```bash
   export PARALLELISM=1
   ./scripts/submit-cdc-job.sh
   ```

### Change Stream Issues

**Symptoms**: Change stream not capturing changes

**Solutions**:
1. Verify change stream retention period
   ```sql
   -- Change streams have a minimum retention of 1 hour
   CREATE CHANGE STREAM ecommerce_change_stream
   FOR customers, products, orders
   OPTIONS (
       retention_period = '1h',
       capture_value_change_type = 'NEW_ROW_AND_OLD_ROW'
   );
   ```

2. Check change stream status
   ```bash
   gcloud spanner change-streams describe ecommerce_change_stream \
     --instance=test-instance \
     --database=ecommerce \
     --project=test-project
   ```

3. Verify partition tokens are being processed
   ```bash
   kubectl logs -l app=flink,component=taskmanager | grep "PartitionToken"
   ```

## Development

### Run Tests

```bash
cd flink-jobs/spanner-cdc
mvn test
```

### Debug Mode

Enable debug logging:
```yaml
# In flink-conf.yaml
rootLogger.level: DEBUG
```

Or via environment:
```bash
export FLINK_LOG_LEVEL=DEBUG
./scripts/submit-cdc-job.sh
```

### Code Structure

```
flink-jobs/spanner-cdc/
├── pom.xml                                    # Maven dependencies
├── src/main/
│   ├── java/com/example/streaming/
│   │   ├── SpannerCdcPipeline.java           # Main pipeline entry point
│   │   ├── model/
│   │   │   ├── Customer.java                 # Customer data model
│   │   │   ├── Product.java                  # Product data model
│   │   │   └── Order.java                    # Order data model
│   │   ├── source/
│   │   │   ├── ModType.java                  # INSERT/UPDATE/DELETE enum
│   │   │   ├── ChangeRecord.java             # CDC data model
│   │   │   ├── SourceState.java              # Checkpointed state
│   │   │   └── SpannerChangeStreamSource.java  # Spanner source
│   │   ├── routing/
│   │   │   └── TableRouterFunction.java      # Table routing logic
│   │   └── sink/
│   │       └── IcebergUpsertSink.java        # Flink Iceberg sink
│   └── resources/
│       ├── flink-conf.yaml                   # Flink configuration
│       └── log4j2.properties                 # Logging config
└── target/
    └── spanner-cdc-bigquery-1.0-SNAPSHOT.jar  # Built JAR

scripts/
├── deploy-all.sh                              # Deploy infrastructure
├── build-cdc-job.sh                           # Build JAR
├── submit-cdc-job.sh                          # Submit to Flink
├── verify-cdc-pipeline.sh                     # Health checks
├── insert-test-data.sh                        # Test data generator
└── setup-spanner-change-stream.sh             # DDL setup
```

## Production Considerations

### High Availability

- Deploy multiple TaskManager replicas
- Use distributed state backend (RocksDB + S3)
- Enable Flink standby JobManagers
- Configure pod disruption budgets

### Security

- Use TLS for emulator connections
- Enable authentication/authorization
- Use secrets for credentials
- Implement network policies

### Monitoring

- Enable Prometheus metrics export
- Configure alerting for:
  - Checkpoint failures
  - Backpressure
  - Record processing lag
  - Pod restarts

### Scalability

- Adjust parallelism based on throughput
- Partition change streams appropriately
- Use Iceberg partitioning for efficient queries (by day, hour, etc.)
- Leverage Iceberg's snapshot isolation for concurrent reads
- Configure MinIO erasure coding for data durability

## License

MIT

## Contributing

Contributions are welcome! Please submit pull requests or open issues for bugs and feature requests.
