package com.example.streaming.source;

import java.sql.Timestamp;
import java.util.Map;

/**
 * Represents a change record from Spanner change stream.
 * Contains table name, modification type, and row data.
 */
public class ChangeRecord {
    private String tableName;
    private ModType modType;
    private Map<String, Object> data;
    private Map<String, Object> oldData;
    private Timestamp commitTimestamp;
    private String recordSequence;
    private String targetTable;

    public ChangeRecord() {}

    public ChangeRecord(String tableName, ModType modType, Map<String, Object> data) {
        this.tableName = tableName;
        this.modType = modType;
        this.data = data;
    }

    // Getters and Setters
    public String getTableName() { return tableName; }
    public void setTableName(String tableName) { this.tableName = tableName; }

    public ModType getModType() { return modType; }
    public void setModType(ModType modType) { this.modType = modType; }

    public Map<String, Object> getData() { return data; }
    public void setData(Map<String, Object> data) { this.data = data; }

    public Map<String, Object> getOldData() { return oldData; }
    public void setOldData(Map<String, Object> oldData) { this.oldData = oldData; }

    public Timestamp getCommitTimestamp() { return commitTimestamp; }
    public void setCommitTimestamp(Timestamp commitTimestamp) { this.commitTimestamp = commitTimestamp; }

    public String getRecordSequence() { return recordSequence; }
    public void setRecordSequence(String recordSequence) { this.recordSequence = recordSequence; }

    public String getTargetTable() { return targetTable; }
    public void setTargetTable(String targetTable) { this.targetTable = targetTable; }

    @Override
    public String toString() {
        return "ChangeRecord{" +
                "table='" + tableName + '\'' +
                ", mod=" + modType +
                ", data=" + data +
                '}';
    }
}
