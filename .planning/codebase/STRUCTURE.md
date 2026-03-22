# Codebase Structure

**Analysis Date:** 2026-03-22

## Directory Layout

```
streaming-processing/
├── v1/                     # Apache Spark implementation
│   ├── config/            # Resource presets for different environments
│   ├── docker-compose.yml # Local development setup
│   ├── helm/             # Kubernetes deployments
│   │   └── streaming-stack/ # Umbrella Helm chart
│   ├── scripts/           # Deployment and verification scripts
│   ├── spark-jobs/        # Scala streaming processor code
│   │   └── streaming-processor/
│   │       └── src/main/
│   │           └── scala/streaming/
│   │               └── CDCContinuousProcessor.scala
│   └── tests/             # E2E and integration tests
├── v2/                   # Version 2 placeholder
├── v3-flink-spanner/      # Apache Flink + Spanner implementation
│   ├── flink-jobs/
│   │   └── spanner-cdc/
│   │       ├── pom.xml   # Maven dependencies
│   │       ├── src/main/
│   │       │   ├── java/com/example/streaming/
│   │       │   │   ├── SpannerCdcPipeline.java     # Main pipeline
│   │       │   │   ├── model/                      # Data models
│   │       │   │   ├── source/                      # CDC sources
│   │       │   │   ├── routing/                    # Processing logic
│   │       │   │   └── sink/                       # Iceberg sink
│   │       │   └── resources/
│   │       └── target/                             # Build artifacts
│   └── scripts/           # Deployment and setup scripts
├── v4-rising-wave/        # RisingWave + PostgreSQL implementation
│   ├── docker-compose.yml # Local development setup
│   ├── .env              # Environment variables
│   ├── sql/              # SQL definitions
│   │   ├── 01-init-postgres.sql
│   │   ├── 02-risingwave-cdc.sql
│   │   └── 03-queries.sql
│   ├── scripts/          # Operational scripts
│   └── docs/             # Documentation
├── v4-redpanda/          # Version 4 placeholder
└── v4-rising-wave/       # Duplicate directory
```

## Directory Purposes

**v1/**
- Purpose: Apache Spark-based streaming pipeline
- Contains: Helm charts, Spark jobs, deployment scripts
- Key files: `[v1/helm/streaming-stack/values.yaml]`, `[v1/spark-jobs/streaming-processor/src/main/scala/streaming/CDCContinuousProcessor.scala]`

**v3-flink-spanner/**
- Purpose: Flink-based Spanner CDC pipeline
- Contains: Maven project, Java streaming jobs, deployment scripts
- Key files: `[v3-flink-spanner/flink-jobs/spanner-cdc/pom.xml]`, `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/SpannerCdcPipeline.java]`

**v4-rising-wave/**
- Purpose: RisingWave-based PostgreSQL CDC pipeline
- Contains: Docker Compose setup, SQL definitions, operational scripts
- Key files: `[v4-rising-wave/docker-compose.yml]`, `[v4-rising-wave/sql/01-init-postgres.sql]`

**scripts/**
- Purpose: Operational and deployment automation
- Contains: Shell scripts for setup, deployment, verification
- Key files: `[v1/scripts/start.sh]`, `[v3-flink-spanner/scripts/deploy-all.sh]`

**docker-compose.yml/**
- Purpose: Local development environment setup
- Contains: Service definitions for local testing
- Key files: `[v1/docker-compose.yml]`, `[v4-rising-wave/docker-compose.yml]`

**helm/**
- Purpose: Kubernetes production deployments
- Contains: Helm charts with Bitnami dependencies
- Key files: `[v1/helm/streaming-stack/values.yaml]`

## Key File Locations

**Entry Points:**
- `[v1/spark-jobs/streaming-processor/src/main/scala/streaming/CDCContinuousProcessor.scala]`: Spark CDC processor
- `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/SpannerCdcPipeline.java]`: Flink pipeline entry point
- `[v4-rising-wave/sql/02-risingwave-cdc.sql]`: RisingWave SQL pipeline

**Configuration:**
- `[v1/helm/streaming-stack/values.yaml]`: Helm chart values
- `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/resources/flink-conf.yaml]`: Flink configuration
- `[v4-rising-wave/.env]`: Environment variables

**Core Logic:**
- `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SpannerHttpSource.java]`: Spanner CDC source
- `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/sink/IcebergUpsertSink.java]`: Iceberg sink implementation

**Testing:**
- `[v1/tests/integration/`: Integration tests
- `[v1/tests/e2e/`: End-to-end tests
- `[v3-flink-spanner/scripts/verify-cdc-pipeline.sh]`: Pipeline verification

## Naming Conventions

**Files:**
- Java: PascalCase for classes, camelCase for methods
  - Example: `SpannerCdcPipeline.java`, `changeRecordToString()`
- Scala: PascalCase for objects, camelCase for methods
  - Example: `CDCContinuousProcessor.scala`, `readFromKafka()`
- SQL: snake_case for tables and columns
  - Example: `customers`, `order_date`

**Directories:**
- kebab-case for directory names
  - Example: `flink-jobs`, `rising-wave`

**Java Package Structure:**
- `com.example.streaming` as root
- Subpackages: `model`, `source`, `sink`, `routing`
- Examples: `com.example.streaming.source.ChangeRecord`

## Where to Add New Code

**New CDC Source:**
- Primary code: `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/]`
- Tests: Add to `[v3-flink-spanner/scripts/]` integration tests

**New Sink Implementation:**
- Primary code: `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/sink/]`
- Configuration: Update `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/resources/flink-conf.yaml]`

**New Processing Pipeline:**
- Spark: `[v1/spark-jobs/streaming-processor/src/main/scala/streaming/]`
- Flink: `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/]`
- SQL: `[v4-rising-wave/sql/]` for RisingWave

**New Deployment:**
- Kubernetes: `[v1/helm/streaming-stack/templates/]`
- Docker Compose: Update root `docker-compose.yml`

## Special Directories

**target/** (Maven build output):
- Purpose: Contains compiled Java artifacts
- Generated: Yes
- Committed: No (should be in .gitignore)

**tests/**:
- Purpose: Integration and E2E test suites
- Generated: No (manual tests)
- Committed: Yes

**helm/streaming-stack/templates/**:
- Purpose: Kubernetes resource templates
- Generated: No
- Committed: Yes

**docs/**:
- Purpose: Project documentation and specifications
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-03-22*