package com.example.streaming;

import com.example.streaming.routing.TableRouterFunction;
import com.example.streaming.sink.BigQueryUpsertSink;
import com.example.streaming.source.ChangeRecord;
import com.example.streaming.source.SpannerChangeStreamSource;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

/**
 * Main Flink pipeline for Spanner to BigQuery CDC.
 *
 * Pipeline flow:
 * 1. SpannerChangeStreamSource - Reads from Spanner (snapshot + change stream)
 * 2. TableRouterFunction - Adds target table metadata
 * 3. BigQueryUpsertSink - Writes to BigQuery with upsert semantics
 */
public class SpannerCdcPipeline {

    public static void main(String[] args) throws Exception {
        // Create execution environment
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // Enable checkpointing for exactly-once semantics
        env.enableCheckpointing(5000); // 5 second checkpoints

        // Configure checkpoint behavior
        env.getCheckpointConfig().setCheckpointingMode(
            org.apache.flink.streaming.api.CheckpointingMode.EXACTLY_ONCE
        );
        env.getCheckpointConfig().setMinPauseBetweenCheckpoints(1000);
        env.getCheckpointConfig().setCheckpointTimeout(60000);
        env.getCheckpointConfig().setMaxConcurrentCheckpoints(1);

        // Configure state backend (use filesystem for local/minikube)
        String stateBackend = System.getenv().getOrDefault("FLINK_STATE_BACKEND", "file:///tmp/flink-checkpoints");
        env.setStateBackend(new org.apache.flink.runtime.state.hashmap.HashMapStateBackend());
        env.getCheckpointConfig().setCheckpointStorage(stateBackend);

        // Create Spanner change stream source
        DataStream<ChangeRecord> changeStream = env.addSource(new SpannerChangeStreamSource())
            .name("spanner-change-stream-source")
            .uid("spanner-source");

        // Route to target tables (adds BigQuery table metadata)
        DataStream<ChangeRecord> routed = changeStream
            .process(new TableRouterFunction())
            .name("table-router")
            .uid("table-router");

        // Sink to BigQuery with upsert semantics
        routed.addSink(new BigQueryUpsertSink())
            .name("bigquery-upsert")
            .uid("bigquery-sink");

        // Execute job
        System.out.println("Starting Spanner CDC Pipeline...");
        System.out.println("Source: Spanner emulator at spanner-emulator:9010");
        System.out.println("Sink: BigQuery emulator at bigquery-emulator:9050");
        System.out.println("State backend: " + stateBackend);

        env.execute("spanner-cdc-bigquery");
    }
}
