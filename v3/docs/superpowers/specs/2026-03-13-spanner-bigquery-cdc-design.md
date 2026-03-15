# Spanner to BigQuery CDC with Flink - Implementation Design

**Date:** 2026-03-13
**Author:** Brainstorming session
**Status:** Approved

---

## Overview

A real-time Change Data Capture (CDC) pipeline that streams changes from Spanner to BigQuery using Apache Flink DataStream API. The pipeline uses Spanner Change Streams API for true CDC (not polling) with exactly-once processing semantics.

**Goal:** Demonstrate real-time data flow from Spanner to BigQuery with proper CDC handling (INSERT/UPDATE/DELETE).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CDC DATA FLOW (Single Change Stream)                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Spanner Emulator                                                           │
│  ┌──────────────────────────────────────────────────────────────┐           │
│  │  1. SNAPSHOT PHASE (one-time)                                 │           │
│  │     For each table: SELECT * FROM table                       │           │
│  │                                                              │           │
│  │  2. CHANGE STREAM PHASE (continuous)                          │           │
│  │     READ ecommerce_change_stream                             │           │
│  │       → Captures: customers, products, orders                │           │
│  │       → Records include: table_name, mod_type, data         │           │
│  └──────────────────────────────────────────────────────────────┘           │
│                                    │                                        │
│                                    ▼                                        │
│   Flink JobManager                                                          │
│  ┌──────────────────────────────────────────────────────────────┐           │
│  │  Single SpannerChangeStreamSource                             │           │
│  │    - Reads ONE change stream for all tables                  │           │
│  │    - Stores change_stream_token in checkpoint                │           │
│  │    - Emits ChangeRecord {table, mod_type, data, timestamp}   │           │
│  │                                                              │           │
│  │  TableRouter (ProcessFunction)                                │           │
│  │    - Routes to: customers_sink, products_sink, orders_sink   │           │
│  └──────────────────────────────────────────────────────────────┘           │
│                                    │                                        │
│                                    ▼                                        │
│   BigQuery Emulator                                                         │
│  ┌──────────────────────────────────────────────────────────────┐           │
│  │  3 separate tables: customers, products, orders              │           │
│  │  Handle: INSERT, UPDATE, DELETE based on mod_type            │           │
│  └──────────────────────────────────────────────────────────────┘           │
│                                                                             │
│   MinIO (Checkpoint Backend)                                                │
│  ┌──────────────────────────────────────────────────────────────┐           │
│  │  State Backup: change_stream_token, phase, last_ts          │           │
│  └──────────────────────────────────────────────────────────────┘           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Single Change Stream Definition

```sql
CREATE CHANGE STREAM ecommerce_change_stream
FOR customers, products, orders
OPTIONS (
    retention_period = '1h',
    capture_value_change_type = 'NEW_ROW_AND_OLD_ROW'
);
```

---

## Change Record Structure

```java
public class ChangeRecord {
    private String tableName;           // "customers" | "products" | "orders"
    private ModType modType;            // INSERT | UPDATE | DELETE
    private Map<String, Object> data;   // New row data
    private Map<String, Object> oldData; // Old row data (for UPDATE/DELETE)
    private Timestamp commitTimestamp;
    private String recordSequence;
    private String targetTable;         // "ecommerce.customers"
}

enum ModType {
    INSERT, UPDATE, DELETE
}
```

---

## Java Class Structure

```
spanner-cdc-bigquery/
├── src/main/java/com/example/streaming/
│   ├── SpannerCdcPipeline.java              # Main entry point, builds Flink job
│   ├── source/
│   │   ├── SpannerChangeStreamSource.java   # Single source for all tables
│   │   ├── ChangeStreamTailClient.java       # Wrapper for change stream API
│   │   └── ChangeRecord.java                 # Data model for CDC records
│   ├── routing/
│   │   └── TableRouterFunction.java          # Routes records to table-specific sinks
│   ├── sink/
│   │   ├── BigQueryUpsertSink.java           # Handles INSERT/UPDATE/DELETE
│   │   └── BigQueryClient.java               # HTTP client for BigQuery emulator
│   └── model/
│       ├── Customer.java
│       ├── Product.java
│       └── Order.java
└── src/main/resources/
    └── flink-conf.yaml
```

---

## State Management & Checkpointing

### Checkpointed State

```
┌─────────────────────────────────────────────────────────┐
│              CHECKPOINTED STATE                         │
├─────────────────────────────────────────────────────────┤
│  phase: "SNAPSHOT" | "CHANGE_STREAM"                    │
│  snapshot_completed: ["customers", "products", "orders"] │
│  change_stream_token: "ChangeStreamTimestampToken(...)  │
│  last_commit_timestamp: 2026-03-13T10:30:45.123Z        │
└─────────────────────────────────────────────────────────┘
```

### Execution Flow

```java
public void run(SourceContext<ChangeRecord> ctx) throws Exception {
    // PHASE 1: SNAPSHOT
    if (state.phase != "CHANGE_STREAM") {
        for (String table : TABLES) {
            if (!state.snapshotCompleted.contains(table)) {
                snapshotTable(table, ctx);
                state.snapshotCompleted.add(table);
            }
        }
        state.phase = "CHANGE_STREAM";
    }

    // PHASE 2: CHANGE STREAM
    while (running) {
        Token token = state.changeStreamToken;

        ChangeStreamResultSet results = tailer.tail(
            "ecommerce_change_stream",
            token,
            state.lastCommitTimestamp
        );

        for (DataChangeRecord record : results) {
            ChangeRecord cr = new ChangeRecord(
                record.getTableName(),
                record.getModType(),
                record.getNewRow(),
                record.getOldRow(),
                record.getCommitTimestamp()
            );
            ctx.collect(cr);

            state.changeStreamToken = record.getToken();
            state.lastCommitTimestamp = record.getCommitTimestamp();
        }
    }
}
```

---

## BigQuery Sink & Routing

### TableRouterFunction

```java
public class TableRouterFunction extends ProcessFunction<ChangeRecord, ChangeRecord> {
    @Override
    public void processElement(ChangeRecord record, Context ctx, Collector<ChangeRecord> out) {
        record.setTargetTable("ecommerce." + record.getTableName());
        out.collect(record);
    }
}
```

### BigQueryUpsertSink

```java
public class BigQueryUpsertSink extends RichSinkFunction<ChangeRecord> {
    private transient BigQueryClient client;

    @Override
    public void open(Configuration params) {
        client = BigQueryClient.builder()
            .endpoint("http://bigquery-emulator:9050")
            .project("test-project")
            .build();
    }

    @Override
    public void invoke(ChangeRecord record) {
        String table = record.getTargetTable();

        switch (record.getModType()) {
            case INSERT:
                client.insert(table, record.getData());
                break;
            case UPDATE:
                client.merge(table, record.getData(), getPrimaryKey(record));
                break;
            case DELETE:
                client.delete(table, getPrimaryKey(record));
                break;
        }
    }
}
```

### Pipeline Configuration

```java
changeStreamStream
    .keyBy(ChangeRecord::getTableName)  // Partition by table
    .addSink(new BigQueryUpsertSink())
    .name("bigquery-upsert");
```

---

## Error Handling

```java
public class SpannerChangeStreamSource extends RichSourceFunction<ChangeRecord> {
    private final int MAX_RETRIES = 3;
    private final long RETRY_DELAY_MS = 1000;

    @Override
    public void run(SourceContext<ChangeRecord> ctx) {
        while (running) {
            try {
                tailChangeStream(ctx);
            } catch (SpannerException e) {
                if (e.getErrorCode() == ErrorCode.DEADLINE_EXCEEDED) {
                    retryWithBackoff();
                } else {
                    throw e;  // Fatal error
                }
            }
        }
    }

    @Override
    public void snapshotState(FunctionSnapshotContext context) {
        checkpointedState.set(state.copy());
    }
}
```

---

## Testing Strategy

### 1. Unit Tests
- ChangeRecord deserialization
- TableRouter logic
- State snapshot/restore

### 2. Integration Tests
- Mock Spanner → Source → Sink → Mock BigQuery
- Verify checkpoint recovery
- Verify all mod_types (INSERT/UPDATE/DELETE)

### 3. End-to-End Test
```bash
# Start all emulators
./scripts/deploy-all.sh

# Initialize Spanner with sample data
./scripts/setup-spanner-change-stream.sh

# Create change stream
gcloud spanner databases ddl update ecommerce --instance=test-instance \
  --ddl="CREATE CHANGE STREAM ecommerce_change_stream FOR customers, products, orders"

# Run Flink job
./scripts/submit-cdc-job.sh

# Insert/update/delete test data
./scripts/insert-test-data.sh

# Verify data in BigQuery
./scripts/verify-cdc.sh
```

---

## Dependencies

```xml
<!-- Existing -->
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-streaming-java_${scala.binary.version}</artifactId>
    <version>${flink.version}</version>
</dependency>
<dependency>
    <groupId>com.google.cloud</groupId>
    <artifactId>google-cloud-spanner</artifactId>
    <version>6.60.0</version>
</dependency>

<!-- New: Spanner Change Streams -->
<dependency>
    <groupId>com.google.cloud</groupId>
    <artifactId>google-cloud-spanner-change-stream</artifactId>
    <version>1.0.0</version>
</dependency>
```

---

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| CDC Method | Change Streams API | True CDC, not polling |
| Source Count | Single source for all tables | Simpler state management |
| Sink Type | Custom Java | Handle DELETE properly |
| State Backend | MinIO | Fault tolerance |
| Exactly-Once | Checkpointed token | No duplicates, no missed changes |

---

## References

- [Spanner Change Streams](https://cloud.google.com/spanner/docs/change-streams)
- [spanner-change-streams-tail](https://github.com/cloudspannerecosystem/spanner-change-streams-tail)
- [Flink SourceFunction](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/datastream/sources/)
- [Flink Checkpointing](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/datastream/fault-tolerance/checkpointing/)
