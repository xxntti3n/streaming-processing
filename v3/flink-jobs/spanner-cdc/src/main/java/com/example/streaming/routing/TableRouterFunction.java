package com.example.streaming.routing;

import com.example.streaming.source.ChangeRecord;
import org.apache.flink.streaming.api.functions.ProcessFunction;

/**
 * Routes change records to their target Iceberg tables.
 * Adds target table metadata for the sink.
 */
public class TableRouterFunction extends ProcessFunction<ChangeRecord, ChangeRecord> {

    private final String namespace;
    private final String catalog;

    public TableRouterFunction() {
        this.namespace = "ecommerce";
        this.catalog = "iceberg";
    }

    @Override
    public void processElement(
        ChangeRecord record,
        Context ctx,
        org.apache.flink.util.Collector<ChangeRecord> out
    ) {
        // Set target table for Iceberg sink (namespace.table format)
        String targetTable = namespace + "." + record.getTableName();
        record.setTargetTable(targetTable);
        out.collect(record);
    }
}
