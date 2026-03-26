package com.example.streaming;

import com.example.streaming.routing.TableRouterFunction;
import com.example.streaming.sink.IcebergUpsertSink;
import com.example.streaming.source.ChangeRecord;
import com.example.streaming.source.SpannerHttpSource;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

/**
 * Main Flink pipeline for Spanner to Iceberg CDC.
 *
 * Pipeline flow:
 * 1. SpannerHttpSource - Reads from Spanner via HTTP API (snapshot + polling)
 * 2. TableRouterFunction - Adds target table metadata
 * 3. IcebergUpsertSink - Writes to Iceberg tables on MinIO
 */
public class SpannerCdcPipeline {

    public static void main(String[] args) throws Exception {
        // Create execution environment
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // Enable checkpointing for exactly-once semantics
        // Configurable via FLINK_CHECKPOINT_INTERVAL_MS environment variable (default: 1000ms)
        long checkpointInterval = Long.parseLong(
            System.getenv().getOrDefault("FLINK_CHECKPOINT_INTERVAL_MS", "1000")
        );
        env.enableCheckpointing(checkpointInterval);

        // Configure checkpoint behavior
        env.getCheckpointConfig().setCheckpointingMode(
            org.apache.flink.streaming.api.CheckpointingMode.EXACTLY_ONCE
        );
        env.getCheckpointConfig().setMinPauseBetweenCheckpoints(500); // Allow more frequent checkpoints
        env.getCheckpointConfig().setCheckpointTimeout(30000); // Faster timeout
        env.getCheckpointConfig().setMaxConcurrentCheckpoints(1);
        env.getCheckpointConfig().setTolerableCheckpointFailureNumber(2); // Allow transient failures

        // Configure state backend (use filesystem for local/minikube)
        String stateBackend = System.getenv().getOrDefault("FLINK_STATE_BACKEND", "file:///tmp/flink-checkpoints");
        env.setStateBackend(new org.apache.flink.runtime.state.hashmap.HashMapStateBackend());
        env.getCheckpointConfig().setCheckpointStorage(stateBackend);

        // Create Spanner HTTP source (avoids SDK classloading issues)
        DataStream<ChangeRecord> changeStream = env.addSource(new SpannerHttpSource())
            .name("spanner-http-source")
            .uid("spanner-source");

        // Route to target tables (adds Iceberg table metadata)
        DataStream<ChangeRecord> routed = changeStream
            .process(new TableRouterFunction())
            .name("table-router")
            .uid("table-router");

        // Sink to Iceberg with upsert semantics
        routed.addSink(new IcebergUpsertSink())
            .name("iceberg-upsert")
            .uid("iceberg-sink");

        // Execute job
        System.out.println("Starting Spanner to Iceberg CDC Pipeline...");
        System.out.println("Source: Spanner HTTP API at " + System.getenv().getOrDefault("SPANNER_EMULATOR_HOST", "spanner-emulator:9010"));
        System.out.println("Sink: Iceberg tables on MinIO (s3a://warehouse)");
        System.out.println("Catalog: " + System.getenv().getOrDefault("ICEBERG_CATALOG_URI",
            System.getenv().getOrDefault("LAKEKEEPER_URI", "http://lakekeeper:8181")));
        System.out.println("State backend: " + stateBackend);
        System.out.println("Checkpoint interval: " + checkpointInterval + "ms");

        env.execute("spanner-cdc-iceberg");
    }
}
