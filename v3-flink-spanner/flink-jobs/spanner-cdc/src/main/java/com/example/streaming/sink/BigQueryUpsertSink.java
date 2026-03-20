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
        // For local development, can be overridden via BIGQUERY_ENDPOINT
        String endpoint = System.getenv().getOrDefault("BIGQUERY_ENDPOINT", "http://bigquery-emulator:9050");
        this.endpoint = endpoint;
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

        switch (table) {
            case "customers":
                return String.valueOf(data.get("customer_id"));
            case "products":
                return String.valueOf(data.get("product_id"));
            case "orders":
                return String.valueOf(data.get("order_id"));
            default:
                return "id";
        }
    }
}
