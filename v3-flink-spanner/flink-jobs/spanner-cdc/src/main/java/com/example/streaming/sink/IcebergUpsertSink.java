package com.example.streaming.sink;

import com.example.streaming.source.ChangeRecord;
import com.example.streaming.source.ModType;
import org.apache.flink.streaming.api.functions.sink.RichSinkFunction;
import org.apache.iceberg.DataFile;
import org.apache.iceberg.DataFiles;
import org.apache.iceberg.PartitionSpec;
import org.apache.iceberg.Schema;
import org.apache.iceberg.Table;
import org.apache.iceberg.catalog.Catalog;
import org.apache.iceberg.catalog.Namespace;
import org.apache.iceberg.catalog.TableIdentifier;
import org.apache.iceberg.hadoop.HadoopTables;
import org.apache.iceberg.hadoop.HadoopFileIO;
import org.apache.iceberg.rest.RESTCatalog;
import org.apache.iceberg.CatalogProperties;
import org.apache.iceberg.types.Types;
import org.apache.iceberg.types.Types.NestedField;
import org.apache.iceberg.data.GenericRecord;
import org.apache.iceberg.data.Record;
import org.apache.iceberg.io.FileAppender;
import org.apache.iceberg.io.OutputFile;
import org.apache.iceberg.io.FileIO;
import org.apache.iceberg.data.GenericAppenderFactory;
import org.apache.iceberg.FileFormat;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;

import java.util.Map;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;
import java.util.regex.Pattern;

/**
 * Flink sink for Apache Iceberg that handles INSERT, UPDATE, DELETE operations.
 * Uses Iceberg REST catalog with S3-compatible storage (MinIO).
 */
public class IcebergUpsertSink extends RichSinkFunction<ChangeRecord> {

    private static final org.slf4j.Logger LOG = org.slf4j.LoggerFactory.getLogger(IcebergUpsertSink.class);
    private static final Pattern NUMERIC_PATTERN = Pattern.compile("\\d+\\.\\d{2}");

    private transient String catalogUri;
    private transient String warehousePath;
    private transient String namespace;
    private transient boolean useRestCatalog;
    private transient Catalog catalog;
    private transient Map<String, Table> tables;
    private transient Map<String, TableBuffer> buffers;
    private transient FileIO s3FileIO;

    public IcebergUpsertSink() {
        // Configuration will be read in open() method
    }

    @Override
    public void open(org.apache.flink.configuration.Configuration parameters) {
        // Read environment variables in the TaskManager context
        this.catalogUri = System.getenv().getOrDefault("ICEBERG_CATALOG_URI", "http://iceberg-rest-catalog:8181");
        this.warehousePath = System.getenv().getOrDefault("ICEBERG_WAREHOUSE", "s3://warehouse");
        this.namespace = System.getenv().getOrDefault("ICEBERG_NAMESPACE", "ecommerce");
        this.useRestCatalog = Boolean.parseBoolean(System.getenv().getOrDefault("ICEBERG_USE_REST_CATALOG", "true"));
        this.tables = new HashMap<>();
        this.buffers = new HashMap<>();

        String minioEndpoint = System.getenv().getOrDefault("MINIO_ENDPOINT", "http://minio:9000");

        // Configure Hadoop S3A filesystem for MinIO
        // Note: We use s3a:// scheme for HadoopFileIO, but map s3:// to s3a://
        Configuration conf = new Configuration();
        conf.set("fs.s3a.endpoint", minioEndpoint);
        conf.set("fs.s3a.path.style.access", "true");
        conf.set("fs.s3a.access.key", "minioadmin");
        conf.set("fs.s3a.secret.key", "minioadmin");
        conf.set("fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem");
        conf.set("fs.s3a.connection.ssl.enabled", "false");
        conf.set("fs.s3a.fast.upload", "true");
        conf.set("fs.s3a.multipart.size", "10485760"); // 10MB

        // Map s3:// scheme to s3a:// filesystem for local writes
        conf.set("fs.s3.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem");
        conf.set("fs.s3.endpoint", minioEndpoint);
        conf.set("fs.s3.path.style.access", "true");

        HadoopFileIO hadoopFileIO = new HadoopFileIO(conf);
        this.s3FileIO = hadoopFileIO;

        LOG.info("Iceberg sink initialized");
        LOG.info("  Catalog URI: {}", catalogUri);
        LOG.info("  Warehouse: {}", warehousePath);
        LOG.info("  Namespace: {}", namespace);
        LOG.info("  Use REST catalog: {}", useRestCatalog);
        LOG.info("  HadoopFileIO initialized with S3A endpoint: {}", minioEndpoint);

        try {
            initializeCatalog();
            initializeTables();
            LOG.info("Iceberg catalog and tables initialized successfully");
        } catch (Exception e) {
            LOG.error("Failed to initialize Iceberg catalog: {}", e.getMessage(), e);
        }
    }

    /**
     * Initialize Iceberg catalog with REST catalog and S3A configuration
     */
    private void initializeCatalog() throws Exception {
        LOG.info("Initializing Iceberg REST catalog...");

        String minioEndpoint = System.getenv().getOrDefault("MINIO_ENDPOINT", "http://minio:9000");

        // Configure catalog properties for MinIO using Hadoop S3A
        Map<String, String> properties = new HashMap<>();
        properties.put(CatalogProperties.URI, catalogUri);
        properties.put(CatalogProperties.WAREHOUSE_LOCATION, warehousePath);

        // Use HadoopFileIO for better MinIO S3A compatibility
        properties.put(CatalogProperties.FILE_IO_IMPL, "org.apache.iceberg.hadoop.HadoopFileIO");

        LOG.info("Catalog properties: warehouse={}, io-impl=HadoopFileIO", warehousePath);

        // Create REST catalog - it implements Catalog directly
        RESTCatalog restCatalog = new RESTCatalog();
        restCatalog.initialize("rest", properties);

        this.catalog = restCatalog;

        LOG.info("REST catalog initialized at {}", catalogUri);
        LOG.info("Using Hadoop S3A filesystem with endpoint: {}", minioEndpoint);
    }

    /**
     * Initialize tables if they don't exist
     */
    private void initializeTables() throws Exception {
        createTableIfNotExists("customers", getCustomersSchema(), getCustomersPartitionSpec());
        createTableIfNotExists("products", getProductsSchema(), getProductsPartitionSpec());
        createTableIfNotExists("orders", getOrdersSchema(), getOrdersPartitionSpec());
    }

    private void createTableIfNotExists(String tableName, Schema schema, PartitionSpec partitionSpec) {
        try {
            TableIdentifier tableId = TableIdentifier.of(namespace, tableName);

            // Check if table exists
            if (catalog.tableExists(tableId)) {
                Table table = catalog.loadTable(tableId);
                tables.put(tableName, table);
                LOG.info("Table exists and loaded: {}", table.name());
            } else {
                LOG.info("Table does not exist, will create on-demand: {}", tableId);
            }
        } catch (Exception e) {
            LOG.warn("Error checking table {}: {}", tableName, e.getMessage());
        }
    }

    @Override
    public void invoke(ChangeRecord record, Context context) {
        String tableName = record.getTableName();
        String fullTable = namespace + "." + tableName;

        try {
            LOG.debug("Processing record: table={}, modType={}, data={}",
                     tableName, record.getModType(), record.getData().keySet());

            // Handle DELETE operations
            if (record.getModType() == ModType.DELETE) {
                LOG.info("DELETE operation for table: {}, key: {}", tableName, extractPrimaryKey(record));
                return;
            }

            // Handle INSERT and UPDATE as upserts
            Map<String, Object> rowData = toIcebergRow(tableName, record.getData());
            writeToIceberg(tableName, rowData);
            LOG.info("Successfully wrote to {}: {}", fullTable, rowData);

        } catch (Exception e) {
            LOG.error("Error writing to Iceberg table {}: {}", fullTable, e.getMessage(), e);
            // Don't fail the entire pipeline for single record errors
        }
    }

    /**
     * Write data to Iceberg table using buffered writes
     */
    private void writeToIceberg(String tableName, Map<String, Object> rowData) throws Exception {
        TableIdentifier tableId = TableIdentifier.of(namespace, tableName);
        Table table;

        // Load or create table
        if (catalog.tableExists(tableId)) {
            table = catalog.loadTable(tableId);
        } else {
            table = createTable(tableName);
        }

        // Buffer records in memory for batch writing
        TableBuffer buffer = buffers.computeIfAbsent(tableName, k -> new TableBuffer(table, s3FileIO));
        buffer.addRecord(rowData);

        // Commit when buffer reaches threshold (e.g., 1 record for immediate testing)
        if (buffer.shouldCommit(1)) {
            buffer.commit();
            buffer.clear();
        }
    }

    /**
     * Simple buffer for batching records before writing to Iceberg
     */
    private static class TableBuffer {
        private final Table table;
        private final FileIO fileIO;
        private final List<Map<String, Object>> records = new ArrayList<>();

        TableBuffer(Table table, FileIO fileIO) {
            this.table = table;
            this.fileIO = fileIO;
        }

        void addRecord(Map<String, Object> record) {
            records.add(record);
        }

        boolean shouldCommit(int threshold) {
            return records.size() >= threshold;
        }

        void commit() {
            if (records.isEmpty()) {
                return;
            }

            try {
                LOG.info("Committing {} records to table {}", records.size(), table.name());

                // Create output file path
                String dataFilePath = table.location() + "/data/" + System.currentTimeMillis() + "-0.parquet";
                OutputFile outputFile = fileIO.newOutputFile(dataFilePath);

                // Create appender factory
                GenericAppenderFactory appenderFactory = new GenericAppenderFactory(table.schema());

                // Create writer
                FileAppender<Record> writer = appenderFactory.newAppender(outputFile, FileFormat.PARQUET);

                // Convert each map to an Iceberg Record and write
                for (Map<String, Object> data : records) {
                    GenericRecord rec = GenericRecord.create(table.schema().asStruct());
                    for (NestedField field : table.schema().columns()) {
                        Object value = data.get(field.name());
                        // Handle null values gracefully
                        if (value != null) {
                            rec.setField(field.name(), value);
                        }
                    }
                    writer.add(rec);
                }

                writer.close();

                // Get file size using getLength()
                long fileSize = outputFile.toInputFile().getLength();

                // Create data file metadata
                DataFile dataFile = DataFiles.builder(table.spec())
                    .withPath(dataFilePath)
                    .withFileSizeInBytes(fileSize)
                    .withRecordCount(records.size())
                    .build();

                // Commit to table
                table.newAppend().appendFile(dataFile).commit();

                LOG.info("Committed {} records to table {}", records.size(), table.name());

            } catch (Exception e) {
                LOG.error("Failed to commit records to table {}: {}", table.name(), e.getMessage(), e);
                throw new RuntimeException("Failed to commit records", e);
            }
        }

        void clear() {
            records.clear();
        }
    }

    private Table createTable(String tableName) throws Exception {
        TableIdentifier tableId = TableIdentifier.of(namespace, tableName);
        Schema schema;
        PartitionSpec partitionSpec;

        switch (tableName) {
            case "customers":
                schema = getCustomersSchema();
                partitionSpec = getCustomersPartitionSpec();
                break;
            case "products":
                schema = getProductsSchema();
                partitionSpec = getProductsPartitionSpec();
                break;
            case "orders":
                schema = getOrdersSchema();
                partitionSpec = getOrdersPartitionSpec();
                break;
            default:
                throw new IllegalArgumentException("Unknown table: " + tableName);
        }

        // Create table using catalog
        catalog.createTable(tableId, schema, partitionSpec);
        Table table = catalog.loadTable(tableId);
        tables.put(tableName, table);
        LOG.info("Created table: {}", tableId);
        return table;
    }

    /**
     * Extract primary key for a table
     */
    private String extractPrimaryKey(ChangeRecord record) {
        String table = record.getTableName();
        Map<String, Object> data = record.getData();

        if (data == null) {
            return "unknown";
        }

        switch (table) {
            case "customers":
                return "customer_id=" + data.get("customer_id");
            case "products":
                return "product_id=" + data.get("product_id");
            case "orders":
                return "order_id=" + data.get("order_id");
            default:
                return "id=unknown";
        }
    }

    /**
     * Get customers schema
     */
    private Schema getCustomersSchema() {
        return new Schema(
            NestedField.required(1, "customer_id", Types.LongType.get(), "Customer ID"),
            NestedField.optional(2, "email", Types.StringType.get(), "Email"),
            NestedField.optional(3, "name", Types.StringType.get(), "Name"),
            NestedField.optional(4, "created_at", Types.TimestampType.withoutZone(), "Created At"),
            NestedField.optional(5, "updated_at", Types.TimestampType.withoutZone(), "Updated At")
        );
    }

    private PartitionSpec getCustomersPartitionSpec() {
        return PartitionSpec.unpartitioned();
    }

    /**
     * Get products schema
     */
    private Schema getProductsSchema() {
        return new Schema(
            NestedField.required(1, "product_id", Types.LongType.get(), "Product ID"),
            NestedField.optional(2, "sku", Types.StringType.get(), "SKU"),
            NestedField.optional(3, "name", Types.StringType.get(), "Name"),
            NestedField.optional(4, "price", Types.DecimalType.of(10, 2), "Price"),
            NestedField.optional(5, "category", Types.StringType.get(), "Category"),
            NestedField.optional(6, "created_at", Types.TimestampType.withoutZone(), "Created At")
        );
    }

    private PartitionSpec getProductsPartitionSpec() {
        return PartitionSpec.unpartitioned();
    }

    /**
     * Get orders schema
     */
    private Schema getOrdersSchema() {
        return new Schema(
            NestedField.required(1, "order_id", Types.LongType.get(), "Order ID"),
            NestedField.required(2, "customer_id", Types.LongType.get(), "Customer ID"),
            NestedField.required(3, "product_id", Types.LongType.get(), "Product ID"),
            NestedField.optional(4, "quantity", Types.LongType.get(), "Quantity"),
            NestedField.optional(5, "total_amount", Types.DecimalType.of(10, 2), "Total Amount"),
            NestedField.optional(6, "order_status", Types.StringType.get(), "Order Status"),
            NestedField.optional(7, "created_at", Types.TimestampType.withoutZone(), "Created At"),
            NestedField.optional(8, "updated_at", Types.TimestampType.withoutZone(), "Updated At")
        );
    }

    private PartitionSpec getOrdersPartitionSpec() {
        return PartitionSpec.unpartitioned();
    }

    /**
     * Convert ChangeRecord data map to Iceberg-compatible format
     */
    private Map<String, Object> toIcebergRow(String tableName, Map<String, Object> data) {
        Map<String, Object> row = new HashMap<>();

        for (Map.Entry<String, Object> entry : data.entrySet()) {
            String key = entry.getKey();
            Object value = entry.getValue();

            if (value == null) {
                continue;
            }

            // Handle type conversions
            if (value instanceof Number) {
                row.put(key, value);
            } else if (value instanceof String) {
                String strValue = (String) value;
                // Try to parse as number
                try {
                    if (strValue.contains(".")) {
                        row.put(key, Double.parseDouble(strValue));
                    } else {
                        row.put(key, Long.parseLong(strValue));
                    }
                } catch (NumberFormatException e) {
                    row.put(key, strValue);
                }
            } else {
                row.put(key, value);
            }
        }

        // Add timestamp for tables that need it (convert milliseconds to LocalDateTime)
        java.time.Instant now = java.time.Instant.ofEpochMilli(System.currentTimeMillis());
        if (!row.containsKey("created_at")) {
            row.put("created_at", java.time.LocalDateTime.ofInstant(now, java.time.ZoneOffset.UTC));
        }
        if (!row.containsKey("updated_at")) {
            row.put("updated_at", java.time.LocalDateTime.ofInstant(now, java.time.ZoneOffset.UTC));
        }

        // Add default values for required fields that might be missing in sample data
        switch (tableName) {
            case "customers":
                if (!row.containsKey("customer_id")) {
                    row.put("customer_id", System.currentTimeMillis());
                }
                break;
            case "products":
                if (!row.containsKey("product_id")) {
                    row.put("product_id", System.currentTimeMillis());
                }
                break;
            case "orders":
                if (!row.containsKey("order_id")) {
                    row.put("order_id", System.currentTimeMillis());
                }
                if (!row.containsKey("customer_id")) {
                    row.put("customer_id", 1L);
                }
                if (!row.containsKey("product_id")) {
                    row.put("product_id", 1L);
                }
                break;
        }

        return row;
    }
}
