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
