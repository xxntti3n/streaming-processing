package com.example.streaming.source;

/**
 * Modification type for CDC records
 */
public enum ModType {
    /** New row inserted */
    INSERT,
    /** Row updated */
    UPDATE,
    /** Row deleted */
    DELETE;

    /**
     * Parse from Spanner change stream mod type string
     * @param value from change stream (typically "INSERT", "UPDATE", "DELETE")
     * @return corresponding ModType
     */
    public static ModType fromString(String value) {
        if (value == null) {
            return INSERT; // Default for new records
        }
        try {
            return ModType.valueOf(value.toUpperCase());
        } catch (IllegalArgumentException e) {
            // Spanner may use different naming, try to map
            String normalized = value.toUpperCase();
            if (normalized.contains("INSERT")) return INSERT;
            if (normalized.contains("UPDATE") || normalized.contains("REPLACE")) return UPDATE;
            if (normalized.contains("DELETE")) return DELETE;
            throw new IllegalArgumentException("Unknown mod type: " + value);
        }
    }
}
