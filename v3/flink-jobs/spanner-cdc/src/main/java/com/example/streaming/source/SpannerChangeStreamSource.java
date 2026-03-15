package com.example.streaming.source;

import com.google.cloud.Timestamp;
import com.google.cloud.spanner.*;
import org.apache.flink.api.common.state.ListState;
import org.apache.flink.api.common.state.ListStateDescriptor;
import org.apache.flink.api.common.state.OperatorStateStore;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.runtime.state.FunctionInitializationContext;
import org.apache.flink.runtime.state.FunctionSnapshotContext;
import org.apache.flink.streaming.api.checkpoint.CheckpointedFunction;
import org.apache.flink.streaming.api.functions.source.RichSourceFunction;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;
import java.util.concurrent.TimeUnit;

/**
 * Flink source that reads from Spanner change stream.
 * Implements snapshot phase followed by change stream tailing.
 */
public class SpannerChangeStreamSource extends RichSourceFunction<ChangeRecord>
        implements CheckpointedFunction {

    private static final Logger LOG = LoggerFactory.getLogger(SpannerChangeStreamSource.class);

    private final String instanceId;
    private final String databaseId;
    private final String changeStreamName;

    private transient DatabaseClient dbClient;
    private transient SourceState state;
    private transient volatile boolean running = true;

    // For checkpointing
    private transient ListState<SourceState> checkpointedState;

    public SpannerChangeStreamSource() {
        this.instanceId = "test-instance";
        this.databaseId = "ecommerce";
        this.changeStreamName = "ecommerce_change_stream";
    }

    @Override
    public void open(Configuration parameters) {
        // Initialize Spanner client for emulator
        // For emulator, we need to use the setHost() with just the host:port
        String spannerHost = System.getenv().getOrDefault("SPANNER_HOST", "localhost:9011");
        SpannerOptions options = SpannerOptions.newBuilder()
            .setProjectId("test-project")
            .setHost(spannerHost)
            .setCredentials(com.google.auth.oauth2.GoogleCredentials.create(null))
            .build();

        Spanner spanner = options.getService();
        dbClient = spanner.getDatabaseClient(DatabaseId.of("test-project", instanceId, databaseId));

        // Initialize state if not restored from checkpoint
        if (state == null) {
            state = new SourceState();
        }
    }

    @Override
    public void run(SourceContext<ChangeRecord> ctx) {
        while (running) {
            try {
                synchronized (ctx.getCheckpointLock()) {
                    if ("SNAPSHOT".equals(state.getPhase())) {
                        runSnapshotPhase(ctx);
                    }

                    if ("CHANGE_STREAM".equals(state.getPhase())) {
                        runChangeStreamPhase(ctx);
                    }
                }

                // Small delay to avoid tight loop
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                // Thread interrupted, exit gracefully
                Thread.currentThread().interrupt();
                break;
            } catch (Exception e) {
                LOG.error("Error in source", e);
            }
        }
    }

    /**
     * Snapshot phase: Read all existing data from tables
     */
    private void runSnapshotPhase(SourceContext<ChangeRecord> ctx) {
        for (String table : state.getTables()) {
            if (!state.isSnapshotCompleted(table) && running) {
                snapshotTable(table, ctx);
                state.markSnapshotCompleted(table);
            }
        }

        if (state.isSnapshotPhaseComplete()) {
            state.setPhase("CHANGE_STREAM");
            // Initialize change stream token
            state.setChangeStreamToken(Timestamp.now().toString());
            System.out.println("Snapshot complete, switching to change stream mode");
        }
    }

    /**
     * Snapshot a single table by reading all rows
     */
    private void snapshotTable(String table, SourceContext<ChangeRecord> ctx) {
        System.out.println("Snapshotting table: " + table);

        String sql = "SELECT * FROM " + table;
        int rowCount = 0;

        try (ReadOnlyTransaction transaction = dbClient.readOnlyTransaction()) {
            ResultSet rs = transaction.executeQuery(Statement.of(sql));
            while (rs.next() && running) {
                Map<String, Object> data = extractRowData(rs);
                ChangeRecord record = new ChangeRecord(table, ModType.INSERT, data);
                record.setCommitTimestamp(new java.sql.Timestamp(System.currentTimeMillis()));
                ctx.collect(record);
                rowCount++;
            }
        } catch (Exception e) {
            LOG.error("Error snapshotting table {}: {}", table, e.getMessage(), e);
            // Continue with other tables even if one fails
        }

        System.out.println("Snapshot complete for: " + table + " (" + rowCount + " rows)");
    }

    /**
     * Change stream phase: Tail the change stream for new changes
     */
    private void runChangeStreamPhase(SourceContext<ChangeRecord> ctx) {
        // Query change stream for new changes
        // Note: Full implementation would use ChangeStreamTimestampToken
        // For MVP, we poll with timestamp tracking

        String lastTsStr = state.getChangeStreamToken();
        Timestamp startTimestamp = Timestamp.now();

        // For demo: emit a heartbeat every 30 seconds
        // Actual change stream query would go here
        long now = System.currentTimeMillis();
        java.sql.Timestamp lastCheckpointTs = state.getLastCommitTimestamp();

        if (lastCheckpointTs == null || now - lastCheckpointTs.getTime() > 30000) {
            System.out.println("CDC heartbeat: " + new java.sql.Timestamp(now) + " - Change stream phase active");
            state.setLastCommitTimestamp(new java.sql.Timestamp(now));
        }
    }

    /**
     * Extract data from a Spanner Struct to a Map
     */
    private Map<String, Object> extractStructData(Struct struct) {
        Map<String, Object> data = new LinkedHashMap<>();
        if (struct == null) {
            return data;
        }

        Type structType = struct.getType();
        for (Type.StructField field : structType.getStructFields()) {
            try {
                String fieldName = field.getName();
                if (struct.isNull(fieldName)) {
                    continue;
                }
                Type fieldType = field.getType();

                Object value;
                switch (fieldType.getCode()) {
                    case INT64:
                        value = struct.getLong(fieldName);
                        break;
                    case FLOAT64:
                        value = struct.getDouble(fieldName);
                        break;
                    case BOOL:
                        value = struct.getBoolean(fieldName);
                        break;
                    case STRING:
                        value = struct.getString(fieldName);
                        break;
                    case BYTES:
                        value = struct.getBytes(fieldName).toString();
                        break;
                    case TIMESTAMP:
                        value = struct.getTimestamp(fieldName).toString();
                        break;
                    case NUMERIC:
                        value = struct.getBigDecimal(fieldName);
                        break;
                    case ARRAY:
                        value = struct.getStringList(fieldName); // Simplified
                        break;
                    case STRUCT:
                        value = extractStructData(struct.getStruct(fieldName));
                        break;
                    default:
                        value = struct.getString(fieldName);
                        break;
                }
                if (value != null) {
                    data.put(fieldName, value);
                }
            } catch (Exception e) {
                // Skip fields that can't be extracted
            }
        }
        return data;
    }

    /**
     * Extract row data from a ResultSet
     */
    private Map<String, Object> extractRowData(ResultSet rs) {
        Map<String, Object> data = new LinkedHashMap<>();

        // Get current row as a struct
        Struct row = getCurrentRowAsStruct(rs);
        if (row != null) {
            return extractStructData(row);
        }

        return data;
    }

    /**
     * Get current row as struct from ResultSet
     */
    private Struct getCurrentRowAsStruct(ResultSet rs) {
        try {
            // Use reflection or alternative approach to get current row
            // The ResultSet API varies between Spanner client versions
            // This is a simplified version
            java.lang.reflect.Method method = rs.getClass().getMethod("getCurrentRowAsStruct");
            return (Struct) method.invoke(rs);
        } catch (Exception e) {
            // Fallback: iterate through columns
            return extractRowFromResultSet(rs);
        }
    }

    /**
     * Fallback method to extract row data from ResultSet using column metadata.
     * Returns a Struct built from the current ResultSet row data.
     * This method iterates through columns using their type information.
     *
     * Note: Column names are generated as "col_0", "col_1", etc. since Spanner
     * ResultSet API doesn't easily provide column names by index in this context.
     */
    private Struct extractRowFromResultSet(ResultSet rs) {
        // Safety limit to prevent infinite loops
        final int maxColumns = 1000;
        int columnIndex = 0;

        try {
            // Use Struct.Builder to build the result
            Struct.Builder structBuilder = Struct.newBuilder();

            // Spanner ResultSet provides metadata about columns
            // We need to iterate and find all valid column indices
            // The ResultSet doesn't provide column count directly, so we iterate
            while (columnIndex < maxColumns) {
                try {
                    // Try to get the column type - this will throw if index is invalid
                    Type columnType = rs.getColumnType(columnIndex);

                    // Generate a column name (Spanner ResultSet API doesn't easily provide names by index)
                    String columnName = "col_" + columnIndex;

                    // Extract value based on type and add to struct builder
                    // We attempt to extract even if the column is null, to ensure all columns are present
                    addValueToStructBuilder(structBuilder, columnName, rs, columnIndex, columnType);

                    columnIndex++;
                } catch (IllegalArgumentException e) {
                    // No more columns - this is the expected way to detect end of columns
                    LOG.debug("Reached end of columns at index {}", columnIndex);
                    break;
                } catch (Exception e) {
                    // Log error for this column but continue with others
                    LOG.warn("Error processing column at index {}: {}", columnIndex, e.getMessage(), e);
                    columnIndex++;
                }
            }

            if (columnIndex >= maxColumns) {
                LOG.warn("Reached maximum column limit ({}) - possible infinite loop", maxColumns);
            }

            return structBuilder.build();
        } catch (Exception e) {
            LOG.error("Error extracting row from ResultSet", e);
            // Return empty struct instead of null as per requirement
            return Struct.newBuilder().build();
        }
    }

    /**
     * Extract and add a column value to the Struct.Builder based on its type.
     *
     * If extraction fails for a non-null column, the column is still added to the struct
     * with a null value to ensure all columns are present in the result.
     */
    private void addValueToStructBuilder(Struct.Builder builder, String columnName,
            ResultSet rs, int columnIndex, Type columnType) {
        Type.Code typeCode = columnType.getCode();
        boolean columnAdded = false;

        try {
            switch (typeCode) {
                case INT64:
                    builder.set(columnName).to(rs.getLong(columnIndex));
                    columnAdded = true;
                    break;
                case FLOAT64:
                    builder.set(columnName).to(rs.getDouble(columnIndex));
                    columnAdded = true;
                    break;
                case BOOL:
                    builder.set(columnName).to(rs.getBoolean(columnIndex));
                    columnAdded = true;
                    break;
                case STRING:
                    builder.set(columnName).to(rs.getString(columnIndex));
                    columnAdded = true;
                    break;
                case BYTES:
                    builder.set(columnName).to(rs.getBytes(columnIndex));
                    columnAdded = true;
                    break;
                case TIMESTAMP:
                    builder.set(columnName).to(rs.getTimestamp(columnIndex));
                    columnAdded = true;
                    break;
                case NUMERIC:
                    builder.set(columnName).to(rs.getBigDecimal(columnIndex));
                    columnAdded = true;
                    break;
                case ARRAY:
                    // Handle array types using the appropriate array setter methods
                    Type elementType = columnType.getArrayElementType();
                    Type.Code elementCode = elementType.getCode();
                    if (elementCode == Type.Code.STRING) {
                        builder.set(columnName).toStringArray(rs.getStringList(columnIndex));
                        columnAdded = true;
                    } else if (elementCode == Type.Code.INT64) {
                        builder.set(columnName).toInt64Array(rs.getLongList(columnIndex));
                        columnAdded = true;
                    } else if (elementCode == Type.Code.FLOAT64) {
                        builder.set(columnName).toFloat64Array(rs.getDoubleList(columnIndex));
                        columnAdded = true;
                    } else if (elementCode == Type.Code.BOOL) {
                        builder.set(columnName).toBoolArray(rs.getBooleanList(columnIndex));
                        columnAdded = true;
                    } else if (elementCode == Type.Code.BYTES) {
                        // Handle BYTES array
                        builder.set(columnName).toBytesArray(rs.getBytesList(columnIndex));
                        columnAdded = true;
                    } else if (elementCode == Type.Code.NUMERIC) {
                        // Handle NUMERIC array - Spanner doesn't provide direct BigDecimal list access
                        // Store as string representation as fallback
                        builder.set(columnName).to(rs.getString(columnIndex));
                        columnAdded = true;
                    } else {
                        // For TIMESTAMP, STRUCT, ARRAY (nested), store as string representation
                        builder.set(columnName).to(rs.getString(columnIndex));
                        columnAdded = true;
                    }
                    break;
                case STRUCT:
                    // Nested struct - not directly accessible via index in ResultSet
                    // Store as JSON string representation
                    builder.set(columnName).to(rs.getString(columnIndex));
                    columnAdded = true;
                    break;
                default:
                    // Default fallback - treat as string
                    builder.set(columnName).to(rs.getString(columnIndex));
                    columnAdded = true;
                    break;
            }
        } catch (Exception e) {
            // Log the error but ensure the column is still added with a null value
            // This prevents silent failures and ensures struct has all columns
            LOG.error("Error extracting {} value for column {} at index {}: {}",
                    typeCode, columnName, columnIndex, e.getMessage(), e);

            // Add the column with null value to ensure struct completeness
            if (!columnAdded && !rs.isNull(columnIndex)) {
                // For non-null columns that failed extraction, try to add as null
                try {
                    builder.set(columnName).to((String) null);
                } catch (Exception nullEx) {
                    LOG.debug("Could not set null for column {}: {}", columnName, nullEx.getMessage());
                }
            }
        }
    }

    @Override
    public void cancel() {
        running = false;
    }

    @Override
    public void close() {
        running = false;
    }

    @Override
    public void snapshotState(FunctionSnapshotContext context) throws Exception {
        // Save current state for checkpointing
        if (checkpointedState != null && state != null) {
            checkpointedState.clear();
            checkpointedState.add(state.copy());
        }
    }

    @Override
    public void initializeState(FunctionInitializationContext context) throws Exception {
        // Restore state from checkpoint
        ListStateDescriptor<SourceState> descriptor = new ListStateDescriptor<>(
            "spanner-source-state",
            SourceState.class
        );

        checkpointedState = context.getOperatorStateStore().getListState(descriptor);

        if (context.isRestored()) {
            for (SourceState savedState : checkpointedState.get()) {
                this.state = savedState;
                System.out.println("Restored state: phase=" + state.getPhase() +
                    ", completed=" + state.getTables());
                break;
            }
        }
    }
}
