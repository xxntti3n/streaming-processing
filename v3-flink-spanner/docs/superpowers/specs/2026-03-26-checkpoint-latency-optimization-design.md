# Checkpoint Latency Optimization Design

**Date:** 2026-03-26
**Status:** Approved
**Author:** Claude + User

## Overview

Reduce Flink CDC pipeline end-to-end latency from 5-10 seconds to 1-3 seconds by tuning checkpoint configuration. This is a configuration-only change that maintains exactly-once semantics.

## Problem

The current v3-flink-spanner CDC pipeline uses 5-second checkpoints, resulting in 5-10 second end-to-end latency from Spanner change to Iceberg write. Users need 1-3 second latency for near real-time analytics.

## Solution

Aggressively tune Flink checkpoint settings to reduce commit interval while maintaining stability.

## Changes

### File: `SpannerCdcPipeline.java`

#### Current Configuration
```java
env.enableCheckpointing(5000); // 5 second checkpoints
env.getCheckpointConfig().setMinPauseBetweenCheckpoints(1000);
env.getCheckpointConfig().setCheckpointTimeout(60000);
env.getCheckpointConfig().setMaxConcurrentCheckpoints(1);
```

#### New Configuration
```java
// Configurable checkpoint interval (default: 1 second)
long checkpointInterval = Long.parseLong(
    System.getenv().getOrDefault("FLINK_CHECKPOINT_INTERVAL_MS", "1000")
);
env.enableCheckpointing(checkpointInterval);

// Allow more frequent checkpoints
env.getCheckpointConfig().setMinPauseBetweenCheckpoints(500);
env.getCheckpointConfig().setCheckpointTimeout(30000);
env.getCheckpointConfig().setMaxConcurrentCheckpoints(1);
env.getCheckpointConfig().setTolerableCheckpointFailureNumber(2);
```

### Configuration Comparison

| Setting | Current | New | Rationale |
|---------|---------|-----|-----------|
| Checkpoint interval | 5000ms | 1000ms | Faster commits = lower latency |
| Min pause between | 1000ms | 500ms | Allow back-to-back checkpoints |
| Timeout | 60000ms | 30000ms | Fail faster, retry quicker |
| Tolerable failures | - | 2 | Allow transient failures |

## Expected Results

| Metric | Current | Target |
|--------|---------|--------|
| End-to-end latency | 5-10s | 1-3s |
| Checkpoint interval | 5s | 1s |
| Checkpoint duration | < 2s | < 500ms |

## Deployment

1. Update `SpannerCdcPipeline.java`
2. Rebuild: `./scripts/build-cdc-job.sh`
3. Resubmit job: `./scripts/submit-cdc-job.sh`

### Optional: Tune via Environment Variable
```bash
export FLINK_CHECKPOINT_INTERVAL_MS=2000  # 2 seconds
./scripts/submit-cdc-job.sh
```

## Validation

1. Insert test data: `./scripts/insert-test-data.sh`
2. Check Flink UI: http://localhost:8081 → Checkpoints tab
3. Verify checkpoint duration < 500ms
4. Measure end-to-end latency

## Rollback Plan

If checkpoint failures or performance issues occur:

```bash
# Option 1: Change environment variable
export FLINK_CHECKPOINT_INTERVAL_MS=5000

# Option 2: Revert code
git checkout SpannerCdcPipeline.java
./scripts/build-cdc-job.sh && ./scripts/submit-cdc-job.sh
```

## Monitoring

Watch for warning signs:
- Checkpoint failures increasing
- Checkpoint duration exceeding interval
- TaskManager CPU spiking
- Backpressure in Flink UI

## Trade-offs

| Pro | Con |
|-----|-----|
| Simple change, minimal code | More checkpoint overhead |
| Achieves 1-3s target | Higher CPU/network usage |
| Maintains exactly-once | Too aggressive (<1s) can cause issues |
| Easy to tune via env var | - |

## Alternatives Considered

- **Approach B:** Sink buffering with more frequent flushes - better for throughput, more complex
- **Approach C:** Continuous processing with streaming upserts - lowest latency, high complexity, metadata bloat

Rejected because Approach A provides the simplest path to the 1-3 second target.
