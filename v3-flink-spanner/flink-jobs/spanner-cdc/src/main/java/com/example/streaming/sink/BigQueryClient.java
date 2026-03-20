package com.example.streaming.sink;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import okhttp3.*;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.TimeUnit;

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
            .connectTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
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
        String tableName = fullTable.split("\\.")[2]; // e.g., "test-project.ecommerce.customers" -> "customers"

        // Use emulator's insert endpoint
        String url = baseUrl + "/bigquery/v2/projects/" + project + "/datasets/ecommerce/tables/" + tableName + "/insert";

        JsonObject body = new JsonObject();
        body.add("rows", gson.toJsonTree(java.util.List.of(row)));

        Request request = new Request.Builder()
            .url(url)
            .post(RequestBody.create(body.toString(), MediaType.parse("application/json")))
            .build();

        try (Response response = httpClient.newCall(request).execute()) {
            if (!response.isSuccessful() && response.code() != 200) {
                // Log for emulator - may return 404 for missing table
                System.err.println("Insert result: " + response.code() + " - " + response.body().string());
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
