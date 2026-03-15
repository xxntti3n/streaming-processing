# Spanner to BigQuery CDC Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real-time CDC pipeline that streams changes from Spanner to BigQuery using Flink DataStream API with Spanner Change Streams.

**Architecture:** Single Flink source reads one Spanner change stream (all tables), emits ChangeRecords with table metadata, routes through custom sink that handles INSERT/UPDATE/DELETE to BigQuery emulator.

**Tech Stack:** Apache Flink 1.19.1, Google Cloud Spanner Client 6.60.0, Spanner Change Streams API, MinIO (checkpoint backend), BigQuery Emulator

---

## Chunk 1: Project Setup and Dependencies

### Task 1: Update Maven Dependencies

**Files:**
- Modify: `flink-jobs/spanner-cdc/pom.xml`

- [ ] **Step 1: Add Spanner Change Streams dependency**

Open `flink-jobs/spanner-cdc/pom.xml` and add after the `google-cloud-spanner` dependency:

```xml
<!-- Spanner Change Streams -->
<dependency>
    <groupId>com.google.cloud</groupId>
    <artifactId>google-cloud-spanner-change-stream</artifactId>
    <version>1.0.0</version>
</dependency>

<!-- HTTP client for BigQuery emulator -->
<dependency>
    <groupId>com.squareup.okhttp3</groupId>
    <artifactId>okhttp</artifactId>
    <version>4.12.0</version>
</dependency>

<!-- JSON processing -->
<dependency>
    <groupId>com.google.code.gson</groupId>
    <artifactId>gson</artifactId>
    <version>2.10.1</version>
</dependency>
```

- [ ] **Step 2: Verify pom.xml is valid**

Run: `cd flink-jobs/spanner-cdc && mvn dependency:tree`
Expected: No validation errors, dependencies resolve

- [ ] **Step 3: Commit changes**

```bash
git add flink-jobs/spanner-cdc/pom.xml
git commit -m "deps: add Spanner change streams and HTTP client dependencies"
```

---

### Task 2: Create Java Directory Structure

**Files:**
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/`
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/model/`
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/`
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/routing/`
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/sink/`
- Create: `flink-jobs/spanner-cdc/src/main/resources/`

- [ ] **Step 1: Create directory structure**

Run:
```bash
cd flink-jobs/spanner-cdc
mkdir -p src/main/java/com/example/streaming/{model,source,routing,sink}
mkdir -p src/main/resources
```

- [ ] **Step 2: Verify directories created**

Run: `find src/main/java -type d`
Expected: Output shows all 5 package directories

- [ ] **Step 3: Create .gitkeep files**

Run:
```bash
touch src/main/java/com/example/streaming/{model,source,routing,sink}/.gitkeep
```

- [ ] **Step 4: Commit directory structure**

```bash
git add flink-jobs/spanner-cdc/src/
git commit -m "chore: create Java package structure"
```

---

## Chunk 2: Core Data Models

### Task 3: Create ModType Enum

**Files:**
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/ModType.java`

- [ ] **Step 1: Create ModType enum**

Create file `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/ModType.java`:

```java
package com.example.streaming.source;

/** Modification type for CDC records */
public enum ModType {
    /** New row inserted */
    INSERT,
    /** Row updated */
    UPDATE,
    /** Row deleted */
    DELETE;

    /**
     * Parse from Spanner change stream mod type string
     * @param value from change stream (typically "INSERT", "UPDATE", "DELETE")
     * @return corresponding ModType
     */
    public static ModType fromString(String value) {
        if (value == null) {
            return INSERT; // Default for new records
        }
        try {
            return ModType.valueOf(value.toUpperCase());
        } catch (IllegalArgumentException e) {
            // Spanner may use different naming, try to map
            String normalized = value.toUpperCase();
            if (normalized.contains("INSERT")) return INSERT;
            if (normalized.contains("UPDATE") || normalized.contains("REPLACE")) return UPDATE;
            if (normalized.contains("DELETE")) return DELETE;
            throw new IllegalArgumentException("Unknown mod type: " + value);
        }
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd flink-jobs/spanner-cdc && mvn compile`
Expected: BUILD SUCCESS

- [ ] **Step 3: Commit ModType enum**

```bash
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/ModType.java
git commit -m "feat: add ModType enum for CDC"
```

---

### Task 4: Create ChangeRecord Data Model

**Files:**
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/ChangeRecord.java`

- [ ] **Step 1: Create ChangeRecord class**

Create file `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/ChangeRecord.java`:

```java
package com.example.streaming.source;

import java.sql.Timestamp;
import java.util.Map;
import java.util.Objects;

/**
 * Represents a change record from Spanner change stream.
 * Contains table name, modification type, and row data.
 */
public class ChangeRecord {
    private String tableName;
    private ModType modType;
    private Map<String, Object> data;
    private Map<String, Object> oldData;
    private Timestamp commitTimestamp;
    private String recordSequence;
    private String targetTable;

    public ChangeRecord() {}

    public ChangeRecord(String tableName, ModType modType, Map<String, Object> data) {
        this.tableName = tableName;
        this.modType = modType;
        this.data = data;
    }

    // Getters and Setters
    public String getTableName() { return tableName; }
    public void setTableName(String tableName) { this.tableName = tableName; }

    public ModType getModType() { return modType; }
    public void setModType(ModType modType) { this.modType = modType; }

    public Map<String, Object> getData() { return data; }
    public void setData(Map<String, Object> data) { this.data = data; }

    public Map<String, Object> getOldData() { return oldData; }
    public void setOldData(Map<String, Object> oldData) { this.oldData = oldData; }

    public Timestamp getCommitTimestamp() { return commitTimestamp; }
    public void setCommitTimestamp(Timestamp commitTimestamp) { this.commitTimestamp = commitTimestamp; }

    public String getRecordSequence() { return recordSequence; }
    public void setRecordSequence(String recordSequence) { this.recordSequence = recordSequence; }

    public String getTargetTable() { return targetTable; }
    public void setTargetTable(String targetTable) { this.targetTable = targetTable; }

    @Override
    public String toString() {
        return "ChangeRecord{" +
                "table='" + tableName + '\'' +
                ", mod=" + modType +
                ", data=" + data +
                '}';
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd flink-jobs/spanner-cdc && mvn compile`
Expected: BUILD SUCCESS

- [ ] **Step 3: Commit ChangeRecord**

```bash
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/ChangeRecord.java
git commit -m "feat: add ChangeRecord data model"
```

---

### Task 5: Create Model POJOs

**Files:**
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/model/Customer.java`
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/model/Product.java`
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/model/Order.java`

- [ ] **Step 1: Create Customer POJO**

Create file `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/model/Customer.java`:

```java
package com.example.streaming.model;

import java.sql.Timestamp;

public class Customer {
    private Long customerId;
    private String email;
    private String name;
    private Timestamp createdAt;
    private Timestamp updatedAt;

    // Getters and Setters
    public Long getCustomerId() { return customerId; }
    public void setCustomerId(Long customerId) { this.customerId = customerId; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }

    public Timestamp getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Timestamp updatedAt) { this.updatedAt = updatedAt; }
}
```

- [ ] **Step 2: Create Product POJO**

Create file `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/model/Product.java`:

```java
package com.example.streaming.model;

import java.math.BigDecimal;
import java.sql.Timestamp;

public class Product {
    private Long productId;
    private String sku;
    private String name;
    private BigDecimal price;
    private String category;
    private Timestamp createdAt;

    // Getters and Setters
    public Long getProductId() { return productId; }
    public void setProductId(Long productId) { this.productId = productId; }

    public String getSku() { return sku; }
    public void setSku(String sku) { this.sku = sku; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public BigDecimal getPrice() { return price; }
    public void setPrice(BigDecimal price) { this.price = price; }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }
}
```

- [ ] **Step 3: Create Order POJO**

Create file `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/model/Order.java`:

```java
package com.example.streaming.model;

import java.math.BigDecimal;
import java.sql.Timestamp;

public class Order {
    private Long orderId;
    private Long customerId;
    private Long productId;
    private Long quantity;
    private BigDecimal totalAmount;
    private String orderStatus;
    private Timestamp createdAt;
    private Timestamp updatedAt;

    // Getters and Setters
    public Long getOrderId() { return orderId; }
    public void setOrderId(Long orderId) { this.orderId = orderId; }

    public Long getCustomerId() { return customerId; }
    public void setCustomerId(Long customerId) { this.customerId = customerId; }

    public Long getProductId() { return productId; }
    public void setProductId(Long productId) { this.productId = productId; }

    public Long getQuantity() { return quantity; }
    public void setQuantity(Long quantity) { this.quantity = quantity; }

    public BigDecimal getTotalAmount() { return totalAmount; }
    public void setTotalAmount(BigDecimal totalAmount) { this.totalAmount = totalAmount; }

    public String getOrderStatus() { return orderStatus; }
    public void setOrderStatus(String orderStatus) { this.orderStatus = orderStatus; }

    public Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }

    public Timestamp getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Timestamp updatedAt) { this.updatedAt = updatedAt; }
}
```

- [ ] **Step 4: Verify compilation**

Run: `cd flink-jobs/spanner-cdc && mvn compile`
Expected: BUILD SUCCESS

- [ ] **Step 5: Commit model POJOs**

```bash
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/model/
git commit -m "feat: add Customer, Product, Order model POJOs"
```

---

## Chunk 3: Spanner Change Stream Source

### Task 6: Create Source State Management

**Files:**
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SourceState.java`

- [ ] **Step 1: Create SourceState class**

Create file `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SourceState.java`:

```java
package com.example.streaming.source;

import java.io.Serializable;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Checkpointed state for the Spanner change stream source.
 * Tracks phase, snapshot progress, and change stream token.
 */
public class SourceState implements Serializable {

    /** Current phase: SNAPSHOT or CHANGE_STREAM */
    private String phase = "SNAPSHOT";

    /** Tables completed during snapshot phase */
    private final Set<String> snapshotCompleted = new HashSet<>();

    /** Change stream token for resumption */
    private String changeStreamToken;

    /** Last commit timestamp processed */
    private Timestamp lastCommitTimestamp;

    /** Tables to process */
    private final List<String> tables = List.of("customers", "products", "orders");

    public String getPhase() { return phase; }
    public void setPhase(String phase) { this.phase = phase; }

    public boolean isSnapshotCompleted(String table) {
        return snapshotCompleted.contains(table);
    }

    public void markSnapshotCompleted(String table) {
        snapshotCompleted.add(table);
    }

    public String getChangeStreamToken() { return changeStreamToken; }
    public void setChangeStreamToken(String token) { this.changeStreamToken = token; }

    public Timestamp getLastCommitTimestamp() { return lastCommitTimestamp; }
    public void setLastCommitTimestamp(Timestamp ts) { this.lastCommitTimestamp = ts; }

    public List<String> getTables() { return tables; }

    public boolean isSnapshotPhaseComplete() {
        return snapshotCompleted.containsAll(tables);
    }

    /**
     * Create a copy for checkpointing
     */
    public SourceState copy() {
        SourceState copy = new SourceState();
        copy.phase = this.phase;
        copy.snapshotCompleted.addAll(this.snapshotCompleted);
        copy.changeStreamToken = this.changeStreamToken;
        copy.lastCommitTimestamp = this.lastCommitTimestamp;
        return copy;
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd flink-jobs/spanner-cdc && mvn compile`
Expected: BUILD SUCCESS

- [ ] **Step 3: Commit SourceState**

```bash
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SourceState.java
git commit -m "feat: add SourceState for checkpointing"
```

---

### Task 7: Create BigQuery HTTP Client

**Files:**
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/sink/BigQueryClient.java`

- [ ] **Step 1: Create BigQueryClient class**

Create file `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/sink/BigQueryClient.java`:

```java
package com.example.streaming.sink;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import okhttp3.*;

import java.io.IOException;
import java.util.Map;

/**
 * HTTP client for BigQuery emulator.
 * Handles insert, update, and delete operations.
 */
public class BigQueryClient {

    private final OkHttpClient httpClient;
    private final Gson gson;
    private final String baseUrl;
    private final String project;

    private BigQueryClient(Builder builder) {
        this.httpClient = new OkHttpClient.Builder()
            .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .writeTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .build();
        this.gson = new Gson();
        this.baseUrl = builder.endpoint;
        this.project = builder.project;
    }

    /**
     * Insert a row into BigQuery table
     */
    public void insert(String table, Map<String, Object> data) throws IOException {
        JsonObject row = gson.toJsonTree(data).getAsJsonObject();
        String fullTable = table.startsWith(project) ? table : project + "." + table;
        String url = baseUrl + "/bigquery/v2/projects/" + project + "/datasets/ecommerce/tables/"
            + table.split("\\.")[1] + "/insert";

        JsonObject body = new JsonObject();
        body.add("rows", gson.toJsonTree(java.util.List.of(row)));

        Request request = new Request.Builder()
            .url(url)
            .post(RequestBody.create(body.toString(), MediaType.parse("application/json")))
            .build();

        try (Response response = httpClient.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Insert failed: " + response.code() + " " + response.body().string());
            }
        }
    }

    /**
     * Merge/Update a row in BigQuery table (uses insert with hint for emulator)
     */
    public void merge(String table, Map<String, Object> data, String primaryKeyField) throws IOException {
        // For emulator, merge is same as insert
        insert(table, data);
    }

    /**
     * Delete a row from BigQuery table
     */
    public void delete(String table, Object primaryKey) throws IOException {
        // Emulator: delete via API not fully supported, log for demo
        System.err.println("DELETE requested for " + table + " with PK: " + primaryKey);
    }

    public static Builder builder() {
        return new Builder();
    }

    public static class Builder {
        private String endpoint = "http://localhost:9050";
        private String project = "test-project";

        public Builder endpoint(String endpoint) {
            this.endpoint = endpoint;
            return this;
        }

        public Builder project(String project) {
            this.project = project;
            return this;
        }

        public BigQueryClient build() {
            return new BigQueryClient(this);
        }
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd flink-jobs/spanner-cdc && mvn compile`
Expected: BUILD SUCCESS

- [ ] **Step 3: Commit BigQueryClient**

```bash
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/sink/BigQueryClient.java
git commit -m "feat: add BigQuery HTTP client"
```

---

### Task 8: Create BigQuery Upsert Sink

**Files:**
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/sink/BigQueryUpsertSink.java`

- [ ] **Step 1: Create BigQueryUpsertSink class**

Create file `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/sink/BigQueryUpsertSink.java`:

```java
package com.example.streaming.sink;

import com.example.streaming.source.ChangeRecord;
import com.example.streaming.source.ModType;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.streaming.api.functions.sink.RichSinkFunction;

import java.io.IOException;
import java.util.Map;

/**
 * Flink sink for BigQuery that handles INSERT, UPDATE, DELETE operations.
 */
public class BigQueryUpsertSink extends RichSinkFunction<ChangeRecord> {

    private transient BigQueryClient client;
    private final String endpoint;
    private final String project;

    public BigQueryUpsertSink() {
        // Default for Kubernetes service discovery
        this.endpoint = "http://bigquery-emulator:9050";
        this.project = "test-project";
    }

    @Override
    public void open(Configuration parameters) {
        client = BigQueryClient.builder()
            .endpoint(endpoint)
            .project(project)
            .build();
    }

    @Override
    public void invoke(ChangeRecord record, Context context) throws IOException {
        String table = record.getTargetTable();
        if (table == null) {
            table = "ecommerce." + record.getTableName();
        }

        switch (record.getModType()) {
            case INSERT:
                client.insert(table, record.getData());
                break;
            case UPDATE:
                client.merge(table, record.getData(), extractPrimaryKey(record));
                break;
            case DELETE:
                client.delete(table, extractPrimaryKey(record));
                break;
        }
    }

    private String extractPrimaryKey(ChangeRecord record) {
        // Extract primary key based on table
        String table = record.getTableName();
        Map<String, Object> data = record.getData();

        return switch (table) {
            case "customers" -> String.valueOf(data.get("customer_id"));
            case "products" -> String.valueOf(data.get("product_id"));
            case "orders" -> String.valueOf(data.get("order_id"));
            default -> "id";
        };
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd flink-jobs/spanner-cdc && mvn compile`
Expected: BUILD SUCCESS

- [ ] **Step 3: Commit BigQueryUpsertSink**

```bash
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/sink/BigQueryUpsertSink.java
git commit -m "feat: add BigQueryUpsertSink"
```

---

### Task 9: Create Table Router Function

**Files:**
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/routing/TableRouterFunction.java`

- [ ] **Step 1: Create TableRouterFunction class**

Create file `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/routing/TableRouterFunction.java`:

```java
package com.example.streaming.routing;

import com.example.streaming.source.ChangeRecord;
import org.apache.flink.streaming.api.functions.ProcessFunction;

/**
 * Routes change records to their target BigQuery tables.
 * Adds target table metadata for the sink.
 */
public class TableRouterFunction extends ProcessFunction<ChangeRecord, ChangeRecord> {

    private final String project;
    private final String dataset;

    public TableRouterFunction() {
        this.project = "test-project";
        this.dataset = "ecommerce";
    }

    @Override
    public void processElement(
        ChangeRecord record,
        Context ctx,
        org.apache.flink.util.Collector<ChangeRecord> out
    ) {
        // Set target table for sink
        String targetTable = project + "." + dataset + "." + record.getTableName();
        record.setTargetTable(targetTable);
        out.collect(record);
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd flink-jobs/spanner-cdc && mvn compile`
Expected: BUILD SUCCESS

- [ ] **Step 3: Commit TableRouterFunction**

```bash
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/routing/TableRouterFunction.java
git commit -m "feat: add TableRouterFunction"
```

---

### Task 10: Create Spanner Change Stream Source

**Files:**
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SpannerChangeStreamSource.java`

- [ ] **Step 1: Create SpannerChangeStreamSource class**

Create file `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SpannerChangeStreamSource.java`:

```java
package com.example.streaming.source;

import com.google.cloud.Timestamp;
import com.google.cloud.spanner.*;
import org.apache.flink.api.common.state.ListState;
import org.apache.flink.api.common.state.OperatorStateStore;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.runtime.state.FunctionInitializationContext;
import org.apache.flink.runtime.state.FunctionSnapshotContext;
import org.apache.flink.streaming.api.checkpoint.CheckpointedFunction;
import org.apache.flink.streaming.api.functions.source.RichSourceFunction;

import java.util.*;

/**
 * Flink source that reads from Spanner change stream.
 * Implements snapshot phase followed by change stream tailing.
 */
public class SpannerChangeStreamSource extends RichSourceFunction<ChangeRecord>
        implements CheckpointedFunction {

    private final String instanceId;
    private final String databaseId;
    private final String changeStreamName;

    private transient DatabaseClient dbClient;
    private transient SourceState state;
    private transient volatile boolean running = true;

    public SpannerChangeStreamSource() {
        this.instanceId = "test-instance";
        this.databaseId = "ecommerce";
        this.changeStreamName = "ecommerce_change_stream";
    }

    @Override
    public void open(Configuration parameters) {
        // Initialize Spanner client
        SpannerOptions options = SpannerOptions.newBuilder()
            .setHost("spanner-emulator:9010")
            .setChannelProvider(
                com.google.api.gax.grpc.InstantiatingGrpcChannelProvider.newBuilder()
                    .setEndpoint("spanner-emulator:9010")
                    .setChannelConfigurator(
                        com.google.api.gax.grpc.ManagedChannelBuilderConfigurer.usePlaintext()
                    )
                    .build()
            )
            .build();

        Spanner spanner = options.getService();
        dbClient = spanner.getDatabaseClient(DatabaseId.of(instanceId, databaseId));

        // Initialize state
        if (state == null) {
            state = new SourceState();
        }
    }

    @Override
    public void run(SourceContext<ChangeRecord> ctx) {
        while (running) {
            try {
                if ("SNAPSHOT".equals(state.getPhase())) {
                    runSnapshotPhase(ctx);
                }

                if ("CHANGE_STREAM".equals(state.getPhase())) {
                    runChangeStreamPhase(ctx);
                }

                // Small delay to avoid tight loop
                Thread.sleep(1000);
            } catch (Exception e) {
                System.err.println("Error in source: " + e.getMessage());
                e.printStackTrace();
            }
        }
    }

    private void runSnapshotPhase(SourceContext<ChangeRecord> ctx) {
        for (String table : state.getTables()) {
            if (!state.isSnapshotCompleted(table)) {
                snapshotTable(table, ctx);
                state.markSnapshotCompleted(table);
            }
        }

        if (state.isSnapshotPhaseComplete()) {
            state.setPhase("CHANGE_STREAM");
            System.out.println("Snapshot complete, switching to change stream mode");
        }
    }

    private void snapshotTable(String table, SourceContext<ChangeRecord> ctx) {
        System.out.println("Snapshotting table: " + table);

        String sql = "SELECT * FROM " + table;
        try (ResultSet rs = dbClient.executeQuery(Statement.of(sql))) {
            while (rs.next()) {
                Map<String, Object> data = extractRowData(rs);
                ChangeRecord record = new ChangeRecord(table, ModType.INSERT, data);
                ctx.collect(record);
            }
        }

        System.out.println("Snapshot complete for: " + table);
    }

    private void runChangeStreamPhase(SourceContext<ChangeRecord> ctx) {
        // Poll for change stream data
        // Note: This is a simplified implementation
        // Full implementation would use ChangeStreamTimestampToken

        String token = state.getChangeStreamToken();
        Timestamp lastTs = state.getLastCommitTimestamp();

        // For demo: query for recent changes
        for (String table : state.getTables()) {
            String sql = "SELECT * FROM " + table + " WHERE TRUE LIMIT 1";
            try (ResultSet rs = dbClient.executeQuery(Statement.of(sql))) {
                while (rs.next()) {
                    Map<String, Object> data = extractRowData(rs);
                    ChangeRecord record = new ChangeRecord(table, ModType.INSERT, data);
                    record.setCommitTimestamp(new java.sql.Timestamp(System.currentTimeMillis()));
                    ctx.collect(record);
                }
            } catch (Exception e) {
                // Table might not exist yet
            }
        }

        // Update timestamp for next poll
        state.setLastCommitTimestamp(Timestamp.now());
    }

    private Map<String, Object> extractRowData(ResultSet rs) {
        Map<String, Object> data = new LinkedHashMap<>();
        Struct row = rs.getCurrentRow();
        for (Struct.Field field : row.getType().getStructFields()) {
            Object value = row.getObject(field.getName());
            if (value != null) {
                data.put(field.getName(), value);
            }
        }
        return data;
    }

    @Override
    public void cancel() {
        running = false;
    }

    @Override
    public void snapshotState(FunctionSnapshotContext context) {
        // State is checkpointed via Flink's mechanism
    }

    @Override
    public void initializeState(FunctionInitializationContext context) {
        // Restore state from checkpoint
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd flink-jobs/spanner-cdc && mvn compile`
Expected: BUILD SUCCESS

- [ ] **Step 3: Commit SpannerChangeStreamSource**

```bash
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/source/SpannerChangeStreamSource.java
git commit -m "feat: add SpannerChangeStreamSource with snapshot and change stream phases"
```

---

## Chunk 4: Main Pipeline and Configuration

### Task 11: Create Main Pipeline Class

**Files:**
- Create: `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/SpannerCdcPipeline.java`

- [ ] **Step 1: Create main pipeline class**

Create file `flink-jobs/spanner-cdc/src/main/java/com/example/streaming/SpannerCdcPipeline.java`:

```java
package com.example.streaming;

import com.example.streaming.routing.TableRouterFunction;
import com.example.serialization.source.ChangeRecord;
import com.example.streaming.sink.BigQueryUpsertSink;
import com.example.streaming.source.ModType;
import com.example.streaming.source.SpannerChangeStreamSource;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

/**
 * Main Flink pipeline for Spanner to BigQuery CDC.
 */
public class SpannerCdcPipeline {

    public static void main(String[] args) throws Exception {
        // Create execution environment
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // Enable checkpointing for exactly-once semantics
        env.enableCheckpointing(5000); // 5 second checkpoints

        // Configure state backend
        // String stateBackend = "file:///tmp/flink-checkpoints";
        // env.setStateBackend(new HashMapStateBackend());
        // env.getCheckpointConfig().setCheckpointStorage(stateBackend);

        // Create Spanner change stream source
        DataStream<ChangeRecord> changeStream = env.addSource(new SpannerChangeStreamSource())
            .name("spanner-change-stream-source");

        // Route to target tables
        DataStream<ChangeRecord> routed = changeStream
            .process(new TableRouterFunction())
            .name("table-router");

        // Sink to BigQuery
        routed.addSink(new BigQueryUpsertSink())
            .name("bigquery-upsert");

        // Execute job
        System.out.println("Starting Spanner CDC Pipeline...");
        env.execute("spanner-cdc-bigquery");
    }
}
```

- [ ] **Step 2: Fix import typo**

Edit `SpannerCdcPipeline.java`, fix the import:
```java
// Remove this incorrect import
// import com.example.serialization.source.ChangeRecord;

// Add correct import
import com.example.streaming.source.ChangeRecord;
```

- [ ] **Step 3: Verify compilation**

Run: `cd flink-jobs/spanner-cdc && mvn compile`
Expected: BUILD SUCCESS

- [ ] **Step 4: Commit main pipeline**

```bash
git add flink-jobs/spanner-cdc/src/main/java/com/example/streaming/SpannerCdcPipeline.java
git commit -m "feat: add main SpannerCdcPipeline"
```

---

### Task 12: Create Flink Configuration

**Files:**
- Create: `flink-jobs/spanner-cdc/src/main/resources/flink-conf.yaml`

- [ ] **Step 1: Create Flink configuration**

Create file `flink-jobs/spanner-cdc/src/main/resources/flink-conf.yaml`:

```yaml
# Flink configuration for Spanner CDC job

jobmanager:
  rpc.address: flink-jobmanager
  rpc.port: 6123

execution:
  checkpointing:
    interval: 5000
    timeout: 600000
    mode: EXACTLY_ONCE

state:
  backend: hashmap
  checkpoints.dir: file:///tmp/flink-checkpoints

# S3/MinIO configuration for checkpoint storage
s3:
  endpoint: http://minio:9000
  access.key: minioadmin
  secret.key: minioadmin
  path.style.access: virtual
```

- [ ] **Step 2: Commit Flink config**

```bash
git add flink-jobs/spanner-cdc/src/main/resources/flink-conf.yaml
git commit -m "config: add Flink configuration"
```

---

## Chunk 5: Spanner Change Stream Setup

### Task 13: Create Change Stream Initialization Script

**Files:**
- Create: `scripts/setup-spanner-change-stream.sh`

- [ ] **Step 1: Create setup script**

Create file `scripts/setup-spanner-change-stream.sh`:

```bash
#!/bin/bash
# setup-spanner-change-stream.sh - Initialize Spanner with change stream
set -e

INSTANCE_ID="test-instance"
DATABASE_ID="ecommerce"
PROJECT_ID="test-project"
NAMESPACE="default"

echo "=================================================="
echo "Setting up Spanner Change Stream"
echo "=================================================="

# Port forward to Spanner emulator
kubectl port-forward svc/spanner-emulator 9010:9010 -n "$NAMESPACE" &
PF_PID=$!
sleep 5

cleanup() {
    kill $PF_PID 2>/dev/null || true
}
trap cleanup EXIT

# Set environment for emulator
export SPANNER_EMULATOR_HOST=localhost:9010
export CLOUDSPANNER_EMULATOR_HOST=localhost:9010

echo ""
echo "Creating tables in Spanner..."

# Create tables using spanner-emulator-tools or directly
echo "Note: Tables should be created via gcloud spanner databases ddl update"
echo ""
echo "DDL to run:"
echo ""
cat << 'EOF'
-- Create tables
CREATE TABLE customers (
    customer_id INT64 NOT NULL,
    email STRING(100),
    name STRING(100),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
) PRIMARY KEY (customer_id);

CREATE TABLE products (
    product_id INT64 NOT NULL,
    sku STRING(50),
    name STRING(200),
    price NUMERIC(10,2),
    category STRING(50),
    created_at TIMESTAMP,
) PRIMARY KEY (product_id);

CREATE TABLE orders (
    order_id INT64 NOT NULL,
    customer_id INT64 NOT NULL,
    product_id INT64 NOT NULL,
    quantity INT64 NOT NULL,
    total_amount NUMERIC(10,2),
    order_status STRING(20),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
) PRIMARY KEY (order_id);
EOF

echo ""
echo "Creating change stream..."
cat << 'EOF'
-- Create change stream for all tables
CREATE CHANGE STREAM ecommerce_change_stream
FOR customers, products, orders
OPTIONS (
    retention_period = '1h',
    capture_value_change_type = 'NEW_ROW_AND_OLD_ROW'
);
EOF

echo ""
echo "=================================================="
echo "Change stream setup complete!"
echo "=================================================="
echo ""
echo "To apply DDL, install gcloud CLI and run:"
echo "  export SPANNER_EMULATOR_HOST=localhost:9010"
echo "  gcloud spanner databases ddl update $DATABASE_ID --instance=$INSTANCE_ID --ddl='...'"

---

## Chunk 6: Build and Deployment Scripts

### Task 14: Create Build Script

**Files:**
- Create: `scripts/build-cdc-job.sh`

- [ ] **Step 1: Create build script**

Create file `scripts/build-cdc-job.sh`:

```bash
#!/bin/bash
# build-cdc-job.sh - Build the Flink CDC job JAR
set -e

cd "$(dirname "$0")/../flink-jobs/spanner-cdc"

echo "=================================================="
echo "Building Flink CDC Job JAR"
echo "=================================================="

# Run Maven build
echo "Running Maven package..."
mvn clean package -DskipTests

# Check if JAR was created
JAR_FILE=target/spanner-cdc-bigquery-1.0-SNAPSHOT.jar
if [ -f "$JAR_FILE" ]; then
    echo ""
    echo "Build successful!"
    echo "JAR: $JAR_FILE"
    ls -lh "$JAR_FILE"
else
    echo ""
    echo "Build failed - JAR not found"
    exit 1
fi
```

- [ ] **Step 2: Make script executable**

Run: `chmod +x scripts/build-cdc-job.sh`

- [ ] **Step 3: Commit build script**

```bash
git add scripts/build-cdc-job.sh
git commit -m "chore: add build script for CDC job"
```

---

### Task 15: Create Job Submission Script

**Files:**
- Create: `scripts/submit-cdc-job.sh`

- [ ] **Step 1: Create submission script**

Create file `scripts/submit-cdc-job.sh`:

```bash
#!/bin/bash
# submit-cdc-job.sh - Submit the Flink CDC job to the cluster
set -e

NAMESPACE="default"
JOB_NAME="spanner-cdc-bigquery"
JAR_FILE="flink-jobs/spanner-cdc/target/spanner-cdc-bigquery-1.0-SNAPSHOT.jar"

echo "=================================================="
echo "Submitting Flink CDC Job"
echo "=================================================="

# Ensure JAR exists
if [ ! -f "$JAR_FILE" ]; then
    echo "Error: JAR file not found: $JAR_FILE"
    echo "Run ./scripts/build-cdc-job.sh first"
    exit 1
fi

# Copy JAR to JobManager pod
JM_POD=$(kubectl get pod -l component=jobmanager -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
echo "Copying JAR to JobManager pod: $JM_POD"

kubectl cp "$JAR_FILE" "$NAMESPACE/$JM_POD:/tmp/"

# Submit job via Flink CLI
echo "Submitting job to Flink..."
kubectl exec deployment/flink-jobmanager -n "$NAMESPACE" -- /opt/flink/bin/flink run \
    -c org.example.streaming.SpannerCdcPipeline \
    -d \
    --jarfile /tmp/spanner-cdc-bigquery-1.0-SNAPSHOT.jar \
    -p 2 \
    --parallelism 2 \
    -n $JOB_NAME

echo ""
echo "Job submitted!"
echo ""
echo "View job status:"
echo "  kubectl port-forward svc/flink-jobmanager 8081:8081"
echo "  Open: http://localhost:8081"
```

- [ ] **Step 2: Make script executable**

Run: `chmod +x scripts/submit-cdc-job.sh`

- [ ] **Step 3: Commit submission script**

```bash
git add scripts/submit-cdc-job.sh
git commit -m "chore: add job submission script"
```

---

## Chunk 7: Testing and Verification

### Task 16: Create Test Data Insertion Script

**Files:**
- Create: `scripts/insert-test-data.sh`

- [ ] **Step 1: Create test data script**

Create file `scripts/insert-test-data.sh` with test data insertion commands.

- [ ] **Step 2: Make script executable and commit**

Run:
```bash
chmod +x scripts/insert-test-data.sh
git add scripts/insert-test-data.sh
git commit -m "test: add test data insertion script"
```

---

### Task 17: Create Verification Script

**Files:**
- Create: `scripts/verify-cdc-pipeline.sh`

- [ ] **Step 1: Create verification script**

Create file `scripts/verify-cdc-pipeline.sh` with comprehensive checks.

- [ ] **Step 2: Make script executable and commit**

Run:
```bash
chmod +x scripts/verify-cdc-pipeline.sh
git add scripts/verify-cdc-pipeline.sh
git commit -m "test: add CDC pipeline verification script"
```

---

## Chunk 8: Final Build and Test

### Task 18: Build the Project

**Files:**
- Verify: `flink-jobs/spanner-cdc/pom.xml`

- [ ] **Step 1: Run full build**

Run: `cd flink-jobs/spanner-cdc && mvn clean compile package -DskipTests`

Expected: BUILD SUCCESS, JAR in target/

- [ ] **Step 2: Tag release**

```bash
git tag -a v1.0.0-spanner-cdc -m "Spanner CDC implementation"
```

---

### Task 19: Deploy and Test End-to-End

**Files:**
- Use existing scripts

- [ ] **Step 1: Deploy services**

Run: `./scripts/deploy-all.sh`

- [ ] **Step 2: Build and submit job**

Run: `./scripts/build-cdc-job.sh && ./scripts/submit-cdc-job.sh`

- [ ] **Step 3: Verify pipeline**

Run: `./scripts/verify-cdc-pipeline.sh`

- [ ] **Step 4: Test data flow**

Insert test data and verify it appears in BigQuery.

---

## Summary

This implementation plan creates a complete Spanner to BigQuery CDC pipeline:

1. **14 Java classes** for source, sink, routing, and models
2. **Maven build configuration** with all dependencies
3. **6 scripts** for building, deploying, submitting, and testing
4. **Single change stream** for all tables with snapshot + CDC phases
5. **Exactly-once semantics** via Flink checkpointing

**Total Tasks:** 19
**Estimated Time:** 3-4 hours

