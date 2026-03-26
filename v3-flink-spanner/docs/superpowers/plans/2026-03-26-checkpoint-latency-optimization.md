# Checkpoint Latency Optimization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce Flink CDC pipeline end-to-end latency from 5-10 seconds to 1-3 seconds by tuning checkpoint configuration.

**Architecture:** Reduce Flink checkpoint interval from 5000ms to 1000ms (configurable via environment variable), adjust related checkpoint settings, and maintain exactly-once semantics.

**Tech Stack:** Apache Flink 1.19.1, Java 11, Kubernetes

---

## File Structure

**Files to modify:**
- `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/SpannerCdcPipeline.java` - Main pipeline entry point

**No new files created.** This is a configuration-only change to existing code.

---

## Chunk 1: Update Checkpoint Configuration

### Task 1: Add configurable checkpoint interval

**Files:**
- Modify: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/SpannerCdcPipeline.java:24-33`

- [ ] **Step 1: Replace hardcoded checkpoint interval with environment variable**

Find lines 24-33:
```java
// Enable checkpointing for exactly-once semantics
env.enableCheckpointing(5000); // 5 second checkpoints

// Configure checkpoint behavior
env.getCheckpointConfig().setCheckpointingMode(
    org.apache.flink.streaming.api.CheckpointingMode.EXACTLY_ONCE
);
env.getCheckpointConfig().setMinPauseBetweenCheckpoints(1000);
env.getCheckpointConfig().setCheckpointTimeout(60000);
env.getCheckpointConfig().setMaxConcurrentCheckpoints(1);
```

Replace with:
```java
// Enable checkpointing for exactly-once semantics
// Configurable via FLINK_CHECKPOINT_INTERVAL_MS environment variable (default: 1000ms)
long checkpointInterval = Long.parseLong(
    System.getenv().getOrDefault("FLINK_CHECKPOINT_INTERVAL_MS", "1000")
);
env.enableCheckpointing(checkpointInterval);

// Configure checkpoint behavior
env.getCheckpointConfig().setCheckpointingMode(
    org.apache.flink.streaming.api.CheckpointingMode.EXACTLY_ONCE
);
env.getCheckpointConfig().setMinPauseBetweenCheckpoints(500); // Allow more frequent checkpoints
env.getCheckpointConfig().setCheckpointTimeout(30000); // Faster timeout
env.getCheckpointConfig().setMaxConcurrentCheckpoints(1);
env.getCheckpointConfig().setTolerableCheckpointFailureNumber(2); // Allow transient failures
```

- [ ] **Step 2: Update logging to show checkpoint interval**

Find lines 56-61 (the logging section):
```java
System.out.println("Starting Spanner to Iceberg CDC Pipeline...");
System.out.println("Source: Spanner HTTP API at " + System.getenv().getOrDefault("SPANNER_EMULATOR_HOST", "spanner-emulator:9010"));
System.out.println("Sink: Iceberg tables on MinIO (s3a://warehouse)");
System.out.println("Catalog: ICEBERG_CATALOG_URI=" + System.getenv().getOrDefault("ICEBERG_CATALOG_URI", "http://iceberg-rest-catalog:8181"));
System.out.println("State backend: " + stateBackend);
```

Add after line 61 (before `env.execute`):
```java
System.out.println("Checkpoint interval: " + checkpointInterval + "ms");
```

- [ ] **Step 3: Verify the file compiles**

Run: `cd flink-jobs/spanner-cdc && mvn compile`

Expected output:
```
[INFO] BUILD SUCCESS
```

If compilation fails, check for:
- Typos in environment variable name
- Correct semicolon placement
- No extra/missing braces

- [ ] **Step 4: Commit the checkpoint configuration changes**

```bash
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/SpannerCdcPipeline.java
git commit -m "feat: reduce checkpoint interval to 1-3 seconds for lower latency

- Add FLINK_CHECKPOINT_INTERVAL_MS env var (default: 1000ms)
- Reduce min pause between checkpoints to 500ms
- Reduce checkpoint timeout to 30s
- Add tolerable checkpoint failure count of 2
- Log checkpoint interval on startup

Target: 1-3 second end-to-end latency
"
```

---

## Chunk 2: Build and Test

### Task 2: Build the JAR

**Files:**
- Script: `scripts/build-cdc-job.sh`

- [ ] **Step 1: Build the Flink job JAR**

Run: `./scripts/build-cdc-job.sh`

Expected output:
```
[INFO] BUILD SUCCESS
[INFO] Total time: XX.XXX s
```

Verify the JAR was created:
```bash
ls -lh flink-jobs/spanner-cdc/target/spanner-cdc-bigquery-1.0-SNAPSHOT.jar
```

Expected: File exists, size ~80-100 MB

- [ ] **Step 2: (Optional) Verify checkpoint configuration is applied**

Run a quick test to ensure the environment variable is read:
```bash
# Test with custom interval
FLINK_CHECKPOINT_INTERVAL_MS=2000 java -cp target/spanner-cdc-bigquery-1.0-SNAPSHOT.jar \
  com.example.streaming.SpannerCdcPipeline --help 2>&1 | grep -i checkpoint || true
```

This may fail (no --help option), but verifies the class is loadable.

---

## Chunk 3: Deployment and Validation

### Task 3: Deploy to Kubernetes (if infrastructure exists)

**Prerequisites:**
- Kubernetes cluster running (kind, minikube, or GKE)
- Flink cluster deployed

- [ ] **Step 1: Check if infrastructure is running**

Run: `kubectl get pods -n default`

If pods are running, proceed. If not, run: `./scripts/deploy-all.sh`

- [ ] **Step 2: Submit the updated job**

Run: `./scripts/submit-cdc-job.sh`

Expected: Job submission succeeds without errors

- [ ] **Step 3: Port forward to Flink UI**

Run: `kubectl port-forward svc/flink-jobmanager 8081:8081`

Visit: http://localhost:8081

- [ ] **Step 4: Verify checkpoint configuration in UI**

1. Navigate to the "Running Jobs" tab
2. Click on "spanner-cdc-iceberg" job
3. Go to "Checkpoints" tab
4. Verify:
   - Checkpoint interval shows ~1000ms (or custom value if FLINK_CHECKPOINT_INTERVAL_MS set)
   - Completed checkpoints are appearing
   - Checkpoint duration is < 500ms

- [ ] **Step 5: Insert test data**

Run: `./scripts/insert-test-data.sh`

- [ ] **Step 6: Measure end-to-end latency**

1. Note the timestamp when test data is inserted
2. Check Flink UI: Checkpoints → verify commits happen within 1-3 seconds
3. Query Iceberg to verify data appears:
```bash
kubectl exec -it deployment/minio -- mc ls local/warehouse/ecommerce/
```

Expected: Data appears within 1-3 seconds of insertion

---

## Chunk 4: Documentation Update

### Task 4: Update README with new configuration

**Files:**
- Modify: `flink-jobs/spanner-cdc/README.md`

- [ ] **Step 1: Add checkpoint configuration to environment variables table**

Find the "Environment Variables" section (around line 395-407).

Add this entry to the table:

| Variable | Default | Description |
|----------|---------|-------------|
| `FLINK_CHECKPOINT_INTERVAL_MS` | `1000` | Checkpoint interval in milliseconds (lower = lower latency, higher = less overhead) |

- [ ] **Step 2: Update the Flink Configuration section**

Find the "Flink Configuration" section (around line 408-429).

Update the example to reflect new defaults:
```yaml
# Checkpointing settings
execution.checkpointing.interval: 1000         # 1 second (was 5000)
execution.checkpointing.mode: exactly_once
execution.checkpointing.timeout: 30000         # 30 seconds (was 60000)
execution.checkpointing.min-pause: 500         # 500ms (was 10000)
execution.checkpointing.max-concurrent-checkpoints: 1
```

- [ ] **Step 3: Commit documentation update**

```bash
git add flink-jobs/spanner-cdc/README.md
git commit -m "docs: update checkpoint configuration documentation

- Add FLINK_CHECKPOINT_INTERVAL_MS env var
- Update Flink config example with new defaults
"
```

---

## Chunk 5: Rollback Procedures (Documentation)

### Task 5: Document rollback procedures

**Files:**
- Modify: `flink-jobs/spanner-cdc/README.md`

- [ ] **Step 1: Add rollback section to Troubleshooting**

Find the "Troubleshooting" section (around line 475).

Add this new subsection after "Checkpoint Failures":

```markdown
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
```

- [ ] **Step 2: Commit rollback documentation**

```bash
git add flink-jobs/spanner-cdc/README.md
git commit -m "docs: add rollback procedures for checkpoint tuning

- Document how to revert checkpoint changes
- Add performance degradation troubleshooting
- Include checkpoint duration monitoring guidance
"
```

---

## Summary

After completing all tasks:

1. ✅ Checkpoint interval reduced from 5s to 1s (configurable)
2. ✅ Related settings optimized (min pause, timeout, failure tolerance)
3. ✅ JAR rebuilt with new configuration
4. ✅ Job deployed and latency verified
5. ✅ Documentation updated with new settings
6. ✅ Rollback procedures documented

**Expected outcome:** 1-3 second end-to-end latency from Spanner change to Iceberg write.

---

## Validation Checklist

After deployment, verify:

- [ ] Checkpoint interval shows 1000ms (or custom value) in Flink UI
- [ ] Checkpoint duration stays < 500ms
- [ ] No checkpoint failures in Flink UI
- [ ] End-to-end latency measured at 1-3 seconds
- [ ] CPU usage is acceptable (no significant spike)
- [ ] No backpressure in Flink UI

If any item fails, see rollback procedures in Chunk 5.
