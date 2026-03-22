# Architecture

**Analysis Date:** 2026-03-22

## Pattern Overview

**Overall:** Multi-version streaming data platform with CDC pipelines

**Key Characteristics:**
- Multiple technology implementations (Spark, Flink, RisingWave)
- Lakehouse architecture using Iceberg format
- Event-driven CDC from relational databases
- Kubernetes-native deployments with Helm charts
- Containerized development environment

## Layers

**Infrastructure Layer:**
- Purpose: Container orchestration and service management
- Location: `v*/helm/`, `v*/docker-compose.yml`
- Contains: Kubernetes manifests, Docker Compose files, Helm charts
- Depends on: Docker, Kubernetes cluster
- Used by: All pipeline versions for deployment

**Data Sources Layer:**
- Purpose: Relational databases with CDC capabilities
- Location: Database configurations, CDC enablement scripts
- Contains: MySQL, PostgreSQL, Spanner source schemas
- Depends on: Database engines with replication support
- Used by: CDC connectors in processing engines

**Processing Layer:**
- Purpose: Stream processing engines for real-time data transformation
- Location: `v*/spark-jobs/`, `v*/flink-jobs/`, `v*/sql/`
- Contains: Streaming applications, SQL definitions
- Depends on: Spark, Flink, RisingWave
- Used by: Data transformation logic

**Storage Layer:**
- Purpose: Data lake with open format storage
- Location: Iceberg tables on MinIO
- Contains: Structured data files, metadata
- Depends on: MinIO, Iceberg REST catalog
- Used by: Analytics queries, BI tools

**Application Layer:**
- Purpose: Query interfaces and verification tools
- Location: `v*/scripts/`, `v*/tests/`
- Contains: Test scripts, verification queries
- Depends on: SQL clients, data validation tools
- Used by: Operations team for monitoring

## Data Flow

**General CDC Pipeline Flow:**

1. **Source Capture**: Database changes captured via CDC (Debezium, logical replication, change streams)
2. **Event Streaming**: Changes streamed through message broker or directly to processor
3. **Stream Processing**: Transformation, enrichment, and routing in processing engine
4. **Lakehouse Storage**: Write to Iceberg tables with proper partitioning and upsert logic
5. **Metadata Management**: Iceberg catalog maintains table schema and file metadata
6. **Query Access**: Analytics engines query latest or historical snapshots

**State Management:**
- Checkpointing for exactly-once semantics (Flink)
- Continuous mode with watermarking (Spark)
- State management for recovery and consistency

## Key Abstractions

**ChangeRecord:**
- Purpose: Represents database change events
- Examples: `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/ChangeRecord.java]`
- Pattern: Immutable data class with operation type (INSERT/UPDATE/DELETE)

**TableRouter:**
- Purpose: Maps source tables to target Iceberg tables
- Examples: `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/routing/TableRouterFunction.java]`
- Pattern: Flink process function with routing logic

**UpsertSink:**
- Purpose: Writes changes to Iceberg with upsert semantics
- Examples: `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/sink/IcebergUpsertSink.java]`
- Pattern: Flink sink function with Iceberg integration

**CDC Processor:**
- Purpose: Main streaming application entry point
- Examples: `[v1/spark-jobs/streaming-processor/src/main/scala/streaming/CDCContinuousProcessor.scala]`
- Pattern: Object-oriented with streaming context

## Entry Points

**Spark CDC Processor (V1):**
- Location: `[v1/spark-jobs/streaming-processor/src/main/scala/streaming/CDCContinuousProcessor.scala]`
- Triggers: Manual submission to Spark cluster
- Responsibilities: Reads from Kafka, writes to Iceberg

**Flink CDC Pipeline (V3):**
- Location: `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/SpannerCdcPipeline.java]`
- Triggers: Flink job submission via REST API
- Responsibilities: Spanner CDC, table routing, Iceberg sink

**RisingWave CDC Pipeline (V4):**
- Location: `[v4-rising-wave/sql/02-risingwave-cdc.sql]`
- Triggers: RisingWave SQL execution
- Responsibilities: PostgreSQL CDC, Iceberg sink creation

## Error Handling

**Strategy:** Layered error handling with checkpoint recovery

**Patterns:**
- Retries with exponential backoff (network connections)
- Dead letter queue for failed records
- Schema evolution support
- Checkpoint-based recovery for exactly-once semantics

## Cross-Cutting Concerns

**Logging:**
- Structured logging with SLF4J
- Log aggregation for distributed systems
- Context propagation across pipeline stages

**Validation:**
- Schema validation at ingestion
- Data quality checks during processing
- Referential integrity maintenance

**Authentication:**
- Service-to-service authentication
- Kubernetes RBAC for deployments
- API key management for external services

---

*Architecture analysis: 2026-03-22*