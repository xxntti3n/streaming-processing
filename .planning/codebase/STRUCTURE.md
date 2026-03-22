# Codebase Structure

**Analysis Date:** 2026-03-22

## Directory Layout

```
streaming-processing/
├── v1/                     # Apache Spark implementation
│   ├── config/            # Resource presets for different environments
│   │   └── resources.yaml
│   ├── docker-compose.yml # Local development setup
│   ├── helm/             # Kubernetes deployments
│   │   └── streaming-stack/ # Umbrella Helm chart
│   │       ├── templates/   # Kubernetes resource templates
│   │       ├── Chart.yaml   # Chart metadata
│   │       ├── values.yaml  # Default values
│   │       ├── values-minimal.yaml
│   │       ├── values-default.yaml
│   │       ├── values-performance.yaml
│   │       └── values-barebones.yaml
│   ├── scripts/           # Deployment and verification scripts
│   ├── spark-jobs/        # Scala streaming processor code
│   │   └── streaming-processor/
│   │       └── src/main/
│   │           └── scala/streaming/
│   │               └── CDCContinuousProcessor.scala
│   └── tests/             # E2E and integration tests
│       ├── e2e/
│       └── integration/
├── v2/                   # Version 2 placeholder
├── v3-flink-spanner/      # Apache Flink + Spanner implementation
│   ├── deployments/      # Kubernetes deployment configurations
│   │   ├── kind-config.yaml
│   │   └── namespace.yaml
│   ├── flink-jobs/
│   │   └── spanner-cdc/
│   │       ├── pom.xml   # Maven dependencies
│   │       ├── src/main/
│   │       │   ├── java/com/example/streaming/
│   │       │   │   ├── SpannerCdcPipeline.java     # Main pipeline
│   │       │   │   ├── model/                      # Data models
│   │       │   │   │   └── ChangeRecord.java
│   │       │   │   ├── source/                      # CDC sources
│   │       │   │   │   ├── SpannerHttpSource.java
│   │       │   │   │   └── ChangeRecord.java
│   │       │   │   ├── routing/                    # Processing logic
│   │       │   │   │   └── TableRouterFunction.java
│   │       │   │   └── sink/                       # Iceberg sink
│   │       │   │       └── IcebergUpsertSink.java
│   │       │   └── resources/
│   │       │       └── flink-conf.yaml             # Flink configuration
│   │       └── target/                             # Build artifacts
│   └── scripts/           # Deployment and setup scripts
│       ├── setup-spanner-go/                       # Spanner setup utilities
│       └── verify-cdc-pipeline.sh                  # Pipeline verification
├── v4-rising-wave/        # RisingWave + PostgreSQL implementation
│   ├── .env              # Environment variables
│   ├── docker-compose.yml # Local development setup (PostgreSQL, MinIO, RisingWave)
│   ├── sql/              # SQL definitions
│   │   ├── 01-init-postgres.sql                   # PostgreSQL setup
│   │   ├── 02-risingwave-cdc.sql                   # CDC pipeline definition
│   │   └── 03-queries.sql                         # Query examples
│   ├── scripts/          # Operational scripts
│   └── docs/             # Documentation
│       ├── superpowers/                           # Project plans and specs
│       │   ├── plans/
│       │   │   └── 2025-03-22-postgres-cdc-risingwave-iceberg.md
│       │   └── specs/
│       │       └── 2025-03-22-postgres-cdc-risingwave-iceberg-design.md
├── v4-redpanda/          # Version 4 placeholder
└── v4-rising-wave/       # Duplicate directory (should be removed)
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
- Key files: `[v4-rising-wave/docker-compose.yml]`, `[v4-rising-wave/sql/02-risingwave-cdc.sql]`, `[v4-rising-wave/.env]`

**scripts/**
- Purpose: Operational and deployment automation
- Contains: Shell scripts for setup, deployment, verification
- Key files: `[v1/scripts/start.sh]`, `[v3-flink-spanner/scripts/deploy-all.sh]`

**docker-compose.yml/** (versioned)
- Purpose: Local development environment setup
- Contains: Service definitions for local testing
- Key files: `[v1/docker-compose.yml]`, `[v4-rising-wave/docker-compose.yml]`

**helm/** (versioned)
- Purpose: Kubernetes production deployments
- Contains: Helm charts with Bitnami dependencies
- Key files: `[v1/helm/streaming-stack/values.yaml]`, environment-specific value files

## Key File Locations

**Entry Points:**
- `[v1/spark-jobs/streaming-processor/src/main/scala/streaming/CDCContinuousProcessor.scala]`: Spark CDC processor
- `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/SpannerCdcPipeline.java]`: Flink pipeline entry point
- `[v4-rising-wave/sql/02-risingwave-cdc.sql]`: RisingWave SQL pipeline

**Configuration:**
- `[v1/helm/streaming-stack/values.yaml]`: Helm chart values
- `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/resources/flink-conf.yaml]`: Flink configuration
- `[v4-rising-wave/.env]`: Environment variables (PostgreSQL, RisingWave, MinIO)
- `[v4-rising-wave/docker-compose.yml]`: Multi-service development setup

**Core Logic:**
- `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SpannerHttpSource.java]`: Spanner CDC source
- `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/sink/IcebergUpsertSink.java]`: Iceberg sink implementation
- `[v3-flink-spanner/flink-jobs/spanner-cdc/src/main/java/com/example/streaming/routing/TableRouterFunction.java]`: Table routing logic

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
- Shell scripts: lowercase with descriptive names
  - Example: `start.sh`, `deploy-all.sh`

**Directories:**
- kebab-case for directory names
  - Example: `flink-jobs`, `rising-wave`, `spark-jobs`

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
- Kubernetes: `[v1/helm/streaming-stack/templates/]` or `[v3-flink-spanner/deployments/]`
- Docker Compose: Add to version-specific docker-compose.yml files

**New Environment Configuration:**
- Helm values: Add to `[v1/helm/streaming-stack/values-*.yaml]`
- Docker Compose: Update version-specific compose files
- Environment variables: Add to `[v4-rising-wave/.env]`

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

**deployments/** (Flink version):
- Purpose: Kubernetes deployment configurations
- Generated: No
- Committed: Yes
- Contains: Kind configuration, namespace definitions

**.env** files:
- Purpose: Environment variable configuration
- Generated: No
- Committed: Yes (for development setup)
- Contains: Service credentials and configuration

---

*Structure analysis: 2026-03-22*