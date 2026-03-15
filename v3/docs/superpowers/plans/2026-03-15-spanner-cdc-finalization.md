# Spanner CDC Pipeline Finalization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the Spanner-to-BigQuery CDC pipeline by implementing placeholder logic, fixing deprecated APIs, adding configuration, and creating documentation.

**Architecture:** Apache Flink reads from Spanner change streams (snapshot phase → CDC phase) and writes to BigQuery with exactly-once semantics via checkpointing.

**Tech Stack:** Apache Flink 1.19.1, Google Cloud Spanner Client 6.60.0, OkHttp 4.12.0, Maven, Java 11+

---

## Existing Codebase Summary

**Already Implemented:**
- `ModType.java` - Enum for INSERT/UPDATE/DELETE with string parser
- `ChangeRecord.java` - CDC data model
- `SourceState.java` - Checkpointed state tracking
- `Customer.java`, `Product.java`, `Order.java` - Entity POJOs
- `TableRouterFunction.java` - Routes records to target tables
- `BigQueryClient.java` - HTTP client for BigQuery emulator
- `BigQueryUpsertSink.java` - RichSinkFunction for CDC
- `SpannerCdcPipeline.java` - Main pipeline entry point
- `pom.xml` - Maven dependencies
- Shell scripts for build, submit, setup, verify

**Gaps to Fill:**
1. `SpannerChangeStreamSource.runChangeStreamPhase()` - Placeholder, needs actual change stream query
2. `SpannerChangeStreamSource.extractRowFromResultSet()` - Returns null, needs fallback implementation
3. `SpannerCdcPipeline` - Uses deprecated `FsStateBackend`, needs migration
4. `flink-conf.yaml` - Missing checkpoint configuration
5. `insert-test-data.sh` - Placeholder, needs actual data insertion
6. `README.md` - Missing setup instructions

---

## Chunk 1: Fix SpannerChangeStreamSource Row Extraction

### Task 1: Implement extractRowFromResultSet fallback

**Files:**
- Modify: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SpannerChangeStreamSource.java:250-254`

- [ ] **Step 1: Read current implementation**

```bash
# Current implementation returns null - need to implement proper fallback
```

- [ ] **Step 2: Implement proper row data extraction**

The fallback should iterate through ResultSet columns using metadata-based extraction. Replace the null return with actual data extraction using Spanner's column metadata API.

- [ ] **Step 3: Compile to verify**

```bash
cd flink-jobs/spanner-cdc && mvn compile
```

Expected: Compilation succeeds without errors

- [ ] **Step 4: Commit**

```bash
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SpannerChangeStreamSource.java
git commit -m "fix: implement proper row extraction fallback for Spanner ResultSet"
```

---

## Chunk 2: Implement Change Stream Query Logic

### Task 2: Implement runChangeStreamPhase with actual change stream query

**Files:**
- Modify: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SpannerChangeStreamSource.java:136-153`

**Context:** The current implementation only emits heartbeats. The change stream phase should query Spanner's change stream using the `changeStreamTimestampToken` for incremental updates.

- [ ] **Step 1: Add change stream query method**

Implement a method that:
1. Uses `state.getChangeStreamToken()` as start timestamp
2. Queries the change stream using `dbClient.changeStream()`
3. Parses change stream results (modType, data, oldData)
4. Emits ChangeRecord for each change
5. Updates `state.setChangeStreamToken()` with latest timestamp

- [ ] **Step 2: Parse change stream mod types**

Change streams return `modType` field with values like `INSERT`, `UPDATE`, `DELETE`. Use `ModType.fromString()` to parse.

- [ ] **Step 3: Handle heartbeat records**

Change streams include heartbeat records for partition tracking. These should be logged but not emitted as ChangeRecords.

- [ ] **Step 4: Compile to verify**

```bash
cd flink-jobs/spanner-cdc && mvn compile
```

Expected: Compilation succeeds

- [ ] **Step 5: Commit**

```bash
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SpannerChangeStreamSource.java
git commit -m "feat: implement change stream query logic with token-based resumption"
```

---

## Chunk 3: Fix Deprecated State Backend

### Task 3: Migrate from FsStateBackend to HashMapStateBackend

**Files:**
- Modify: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/SpannerCdcPipeline.java:36-37`

**Context:** `FsStateBackend` is deprecated in Flink 1.19+. Use `HashMapStateBackend` with checkpoint storage configured separately.

- [ ] **Step 1: Update state backend initialization**

Change from:
```java
env.setStateBackend(new org.apache.flink.runtime.state.filesystem.FsStateBackend(stateBackend));
```

To:
```java
env.setStateBackend(new org.apache.flink.runtime.state.hashmap.HashMapStateBackend());
env.getCheckpointConfig().setCheckpointStorage(stateBackend);
```

- [ ] **Step 2: Compile to verify**

```bash
cd flink-jobs/spanner-cdc && mvn compile
```

Expected: Compilation succeeds, no deprecation warnings for state backend

- [ ] **Step 3: Commit**

```bash
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/SpannerCdcPipeline.java
git commit -m "fix: migrate from deprecated FsStateBackend to HashMapStateBackend"
```

---

## Chunk 4: Add Flink Configuration File

### Task 4: Create flink-conf.yaml for checkpoint configuration

**Files:**
- Create: `flink-jobs/spanner-cdc/src/main/resources/flink-conf.yaml`

- [ ] **Step 1: Create resources directory**

```bash
mkdir -p flink-jobs/spanner-cdc/src/main/resources
```

- [ ] **Step 2: Create flink-conf.yaml**

```yaml
# Flink configuration for Spanner CDC job
state.backend: hashmap
state.checkpoints.dir: file:///tmp/flink-checkpoints
checkpoint.interval: 5000
checkpointing-mode: EXACTLY_ONCE
checkpoint.timeout: 60000
checkpoint.min-pause: 1000
checkpoint.max-concurrent-checkpoints: 1
restart-strategy: fixed-delay
restart-strategy.fixed-delay.attempts: 3
restart-strategy.fixed-delay.delay: 10000
```

- [ ] **Step 3: Commit**

```bash
git add flink-jobs/spanner-cdc/src/main/resources/flink-conf.yaml
git commit -m "feat: add Flink configuration with checkpoint settings"
```

---

## Chunk 5: Complete Test Data Insertion Script

### Task 5: Implement actual data insertion in insert-test-data.sh

**Files:**
- Modify: `scripts/insert-test-data.sh:36-78`

**Context:** Current script is a placeholder. Need to use `gcloud spanner rows insert` or implement direct HTTP calls to Spanner emulator.

- [ ] **Step 1: Implement customer insertion**

Add logic to insert 5 test customers using gcloud CLI or direct HTTP to Spanner emulator endpoint.

- [ ] **Step 2: Implement product insertion**

Add logic to insert 5 test products.

- [ ] **Step 3: Implement order insertion**

Add logic to insert 3 test orders.

- [ ] **Step 4: Make script executable**

```bash
chmod +x scripts/insert-test-data.sh
```

- [ ] **Step 5: Commit**

```bash
git add scripts/insert-test-data.sh
git commit -m "feat: implement actual test data insertion in insert-test-data.sh"
```

---

## Chunk 6: Create README Documentation

### Task 6: Write comprehensive README with setup instructions

**Files:**
- Create: `flink-jobs/spanner-cdc/README.md`

- [ ] **Step 1: Create README with sections:**
  - Project Overview
  - Architecture Diagram
  - Prerequisites (Docker, kubectl, Maven, Java 11+)
  - Local Development Setup
  - Building the JAR
  - Deploying to Kubernetes
  - Verifying the Pipeline
  - Troubleshooting

- [ ] **Step 2: Include architecture diagram**

```
Spanner (Emulator)        Flink Cluster          BigQuery (Emulator)
      |                         |                        |
      |--CDC Changes--> [Source]-->[Router]-->[Sink] --|
                           |          |          |
                        Checkpoint   Target     Upsert
                           State      Table     Logic
```

- [ ] **Step 3: Add example commands**

```bash
# Build
./scripts/build-cdc-job.sh

# Deploy infrastructure (assuming Helm charts exist)
helm install spanner-emulator ./helm/spanner-emulator
helm install flink ./helm/flink
helm install bigquery-emulator ./helm/bigquery-emulator

# Setup Spanner tables and change stream
./scripts/setup-spanner-change-stream.sh

# Submit Flink job
./scripts/submit-cdc-job.sh

# Insert test data
./scripts/insert-test-data.sh

# Verify
./scripts/verify-cdc-pipeline.sh
```

- [ ] **Step 4: Commit**

```bash
git add flink-jobs/spanner-cdc/README.md
git commit -m "docs: add comprehensive README with setup instructions"
```

---

## Chunk 7: Fix Port Configuration

### Task 7: Align emulator port configuration

**Files:**
- Modify: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SpannerChangeStreamSource.java:45`
- Modify: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/sink/BigQueryUpsertSink.java:23`

**Context:** Default ports in code (9011 for Spanner, 9050 for BigQuery) may differ from Helm chart defaults. Ensure consistency.

- [ ] **Step 1: Update Spanner host default**

Change from `localhost:9011` to `spanner-emulator:9010` for Kubernetes deployment compatibility.

- [ ] **Step 2: Update BigQuery endpoint default**

Change from `localhost:9050` to `bigquery-emulator:9050` for Kubernetes deployment compatibility.

- [ ] **Step 3: Add environment variable documentation**

Document required environment variables in README:
- `SPANNER_HOST` - Spanner emulator host:port (default: spanner-emulator:9010)
- `BIGQUERY_ENDPOINT` - BigQuery emulator endpoint (default: http://bigquery-emulator:9050)
- `FLINK_STATE_BACKEND` - Checkpoint storage location

- [ ] **Step 4: Compile and commit**

```bash
cd flink-jobs/spanner-cdc && mvn compile
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SpannerChangeStreamSource.java
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/sink/BigQueryUpsertSink.java
git commit -m "fix: align emulator port configuration with Kubernetes service names"
```

---

## Chunk 8: End-to-End Testing

### Task 8: Build and verify complete pipeline

**Files:**
- Test: All components

- [ ] **Step 1: Build the JAR**

```bash
./scripts/build-cdc-job.sh
```

Expected: Build succeeds, JAR created at `flink-jobs/spanner-cdc/target/spanner-cdc-bigquery-1.0-SNAPSHOT.jar`

- [ ] **Step 2: Verify JAR contents**

```bash
jar tf flink-jobs/spanner-cdc/target/spanner-cdc-bigquery-1.0-SNAPSHOT.jar | grep -E "(SpannerCdcPipeline|ModType|ChangeRecord)"
```

Expected: Output shows main class and model classes are bundled

- [ ] **Step 3: Run infrastructure verification**

```bash
./scripts/verify-cdc-pipeline.sh
```

Expected: All infrastructure checks pass

- [ ] **Step 4: Document test results**

Create a test report documenting:
- Build status
- Infrastructure deployment status
- CDC job submission status
- Any issues found and resolutions

- [ ] **Step 5: Final commit**

```bash
git add docs/
git commit -m "test: add E2E test results report"
```

---

## Verification Checklist

After completing all chunks:

- [ ] Code compiles without errors
- [ ] No deprecation warnings for state backend
- [ ] JAR file includes all dependencies
- [ ] Scripts are executable
- [ ] README is comprehensive
- [ ] Environment variables are documented
- [ ] Port configuration is consistent across code and Helm charts

---

## Additional Notes

**Change Stream API Reference:**
- Use `dbClient.changeStreamQuery()` to query change streams
- Parse `ChangeStreamRecord` for modType, data, oldData
- Use `ChangeStreamTimestampToken` for resumption

**BigQuery Emulator API:**
- Endpoint: `http://bigquery-emulator:9050/bigquery/v2/`
- Insert: `POST /projects/{project}/datasets/{dataset}/tables/{table}/insert`
- Update: Use insert with merge hint for emulator

**Troubleshooting:**
- Checkpoint failures: Verify `/tmp/flink-checkpoints` is writable
- Spanner connection: Verify `SPANNER_HOST` environment variable
- Change stream not found: Run `setup-spanner-change-stream.sh` first
