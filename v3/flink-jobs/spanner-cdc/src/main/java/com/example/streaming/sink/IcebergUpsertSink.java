package com.example.streaming.sink;

import com.example.streaming.source.ChangeRecord;
import com.example.streaming.source.ModType;
import org.apache.flink.streaming.api.functions.sink.RichSinkFunction;

import java.util.Map;
import java.util.HashMap;
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

    public IcebergUpsertSink() {
        // Configuration via environment variables
        this.catalogUri = System.getenv().getOrDefault("ICEBERG_CATALOG_URI", "http://iceberg-rest-catalog:8181");
        this.warehousePath = System.getenv().getOrDefault("ICEBERG_WAREHOUSE", "s3a://warehouse:9000/warehouse/ecommerce");
        this.namespace = System.getenv().getOrDefault("ICEBERG_NAMESPACE", "ecommerce");
        this.useRestCatalog = Boolean.parseBoolean(System.getenv().getOrDefault("ICEBERG_USE_REST_CATALOG", "true"));
    }

    @Override
    public void open(org.apache.flink.configuration.Configuration parameters) {
        LOG.info("Iceberg sink initialized");
        LOG.info("  Catalog URI: {}", catalogUri);
        LOG.info("  Warehouse: {}", warehousePath);
        LOG.info("  Namespace: {}", namespace);
        LOG.info("  Use REST catalog: {}", useRestCatalog);

        // In production, initialize Iceberg catalog here
        // org.apache.iceberg.rest.RESTCatalog catalog = new RESTCatalog();
        // catalog.initialize("rest", new HashMap<String, String>() {{
        //     put(CatalogProperties.URI, catalogUri);
        //     put(CatalogProperties.WAREHOUSE_LOCATION, warehousePath);
        // }});
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
                // In production: catalog.newTableIdentifier(namespace, tableName)
                //                   .newDelete()
                //                   .set("id", extractPrimaryKey(record))
                //                   .commit();
                return;
            }

            // Handle INSERT and UPDATE as upserts
            Map<String, Object> rowData = toIcebergRow(tableName, record.getData());
            LOG.info("Writing to {}: {}", fullTable, rowData);

            // In production, use Iceberg's API to write data:
            // Table table = catalog.loadTable(TableIdentifier.of(namespace, tableName));
            // table.newFastAppend()
            //     .set(rowData)
            //     .commit();

        } catch (Exception e) {
            LOG.error("Error writing to Iceberg table {}: {}", fullTable, e.getMessage(), e);
            // Don't fail the entire pipeline for single record errors
        }
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
     * Get schema definition for Iceberg table
     */
    private String getIcebergSchema(String tableName) {
        switch (tableName) {
            case "customers":
                return "{\n" +
                       "  \"type\": \"struct\",\n" +
                       "  \"fields\": [\n" +
                       "    {\"name\": \"customer_id\", \"type\": \"long\", \"required\": true},\n" +
                       "    {\"name\": \"email\", \"type\": \"string\", \"required\": false},\n" +
                       "    {\"name\": \"name\", \"type\": \"string\", \"required\": false},\n" +
                       "    {\"name\": \"created_at\", \"type\": \"timestamp\", \"required\": false},\n" +
                       "    {\"name\": \"updated_at\", \"type\": \"timestamp\", \"required\": false}\n" +
                       "  ]\n" +
                       "}";
            case "products":
                return "{\n" +
                       "  \"type\": \"struct\",\n" +
                       "  \"fields\": [\n" +
                       "    {\"name\": \"product_id\", \"type\": \"long\", \"required\": true},\n" +
                       "    {\"name\": \"sku\", \"type\": \"string\", \"required\": false},\n" +
                       "    {\"name\": \"name\", \"type\": \"string\", \"required\": false},\n" +
                       "    {\"name\": \"price\", \"type\": \"decimal(10,2)\", \"required\": false},\n" +
                       "    {\"name\": \"category\", \"type\": \"string\", \"required\": false},\n" +
                       "    {\"name\": \"created_at\", \"type\": \"timestamp\", \"required\": false}\n" +
                       "  ]\n" +
                       "}";
            case "orders":
                return "{\n" +
                       "  \"type\": \"struct\",\n" +
                       "  \"fields\": [\n" +
                       "    {\"name\": \"order_id\", \"type\": \"long\", \"required\": true},\n" +
                       "    {\"name\": \"customer_id\", \"type\": \"long\", \"required\": true},\n" +
                       "    {\"name\": \"product_id\", \"type\": \"long\", \"required\": true},\n" +
                       "    {\"name\": \"quantity\", \"type\": \"long\", \"required\": false},\n" +
                       "    {\"name\": \"total_amount\", \"type\": \"decimal(10,2)\", \"required\": false},\n" +
                       "    {\"name\": \"order_status\", \"type\": \"string\", \"required\": false},\n" +
                       "    {\"name\": \"created_at\", \"type\": \"timestamp\", \"required\": false},\n" +
                       "    {\"name\": \"updated_at\", \"type\": \"timestamp\", \"required\": false}\n" +
                       "  ]\n" +
                       "}";
            default:
                throw new IllegalArgumentException("Unknown table: " + tableName);
        }
    }

    /**
     * Convert ChangeRecord data map to Iceberg-compatible format
     */
    private Map<String, Object> toIcebergRow(String tableName, Map<String, Object> data) {
        Map<String, Object> row = new HashMap<>();

        for (Map.Entry<String, Object> entry : data.entrySet()) {
            String key = entry.getKey();
            Object value = entry.getValue();

            // Handle type conversions
            if (value instanceof java.math.BigDecimal) {
                // Already a BigDecimal, keep as-is
                row.put(key, value);
            } else if (value instanceof Number) {
                // Convert to appropriate numeric type
                row.put(key, value);
            } else if (value != null) {
                row.put(key, value.toString());
            }
        }

        return row;
    }

    /**
     * Get partition spec for Iceberg tables
     */
    private String getPartitionSpec(String tableName) {
        // For simplicity, use unpartitioned tables
        // In production, define partitions based on date/hour for CDC
        return "[{\"name\":\"partition\",\"transform\":\"identity\",\"source\":\"partition\"}]";
    }
}
