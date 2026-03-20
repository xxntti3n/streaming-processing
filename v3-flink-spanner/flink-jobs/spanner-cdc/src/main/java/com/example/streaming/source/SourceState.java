package com.example.streaming.source;

import java.io.Serializable;
import java.sql.Timestamp;
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
