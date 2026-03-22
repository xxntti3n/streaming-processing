# Coding Conventions

**Analysis Date:** 2026-03-22

## Language Conventions

### Python Scripts

**File Naming:**
- Use descriptive names: `setup_spanner_grpc.py`, `setup-spanner.py`
- Use kebab-case or snake_case
- Start with `setup_` for utility scripts

**Code Style:**
- Use `#!/usr/bin/env python3` shebang
- Include module docstrings
- Use triple quotes for multi-line strings
- Follow PEP 8 for indentation (4 spaces)
- Use meaningful variable names (`EMULATOR_HOST`, `INSTANCE_ID`)
- Constants in uppercase: `PROJECT_ID = "test-project"`

**Error Handling:**
```python
try:
    # operation
except Exception as e:
    if 'AlreadyExists' in str(e):
        # Handle specific case
    else:
        raise
```

**Import Organization:**
- Standard library first: `import os`, `import time`
- Third-party imports next: `import grpc`, `from google.cloud import spanner`
- Group related imports together
- Use try-except for optional dependencies

### Java/Scala Code

**File Naming:**
- PascalCase for classes: `SpannerCdcPipeline.java`
- CamelCase for methods and variables: `createInstance()`, `changeStream`

**Package Structure:**
- Group by functionality: `com.example.streaming.sink`, `com.example.streaming.source`
- Follow domain-driven organization

**Code Style:**
- Use JavaDoc comments for classes:
```java
/**
 * Main Flink pipeline for Spanner to Iceberg CDC.
 *
 * Pipeline flow:
 * 1. SpannerHttpSource - Reads from Spanner via HTTP API
 * 2. TableRouterFunction - Adds target table metadata
 * 3. IcebergUpsertSink - Writes to Iceberg tables
 */
```
- Use SLF4J for logging: `private static final Logger LOG = LoggerFactory.getLogger(ClassName.class)`
- Use meaningful constants: `private static final Pattern NUMERIC_PATTERN = Pattern.compile("\\d+\\.\\d{2}")`

**Error Handling:**
- Use exception handling appropriately
- Provide meaningful error messages
- Log errors with context

## SQL Conventions

**File Naming:**
- Use numbered prefixes for order: `01-init-postgres.sql`, `02-risingwave-cdc.sql`
- Include component name: `postgres-cdc.sql`

**SQL Style:**
- Keywords uppercase: `CREATE TABLE`, `INSERT INTO`
- Reserved words in quotes: `"uuid-ossp"`
- Use clear table and column names
- Add comments with `--`
- Structure SQL with sections:

```sql
-- ============================================================================
-- Customers table
-- ============================================================================

CREATE TABLE IF NOT EXISTS customers (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name VARCHAR NOT NULL,
    email VARCHAR UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better CDC performance
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
```

**Template Pattern:**
- Use `CREATE TABLE IF NOT EXISTS` for idempotency
- Include `DEFAULT CURRENT_TIMESTAMP` for timestamps
- Add comments explaining purpose
- Group related objects with clear separation

## Shell Script Conventions

**File Naming:**
- Descriptive names: `connectivity-test.sh`, `run-e2e.sh`
- Use kebab-case

**Code Style:**
- Start with shebang: `#!/bin/bash`
- Use `set -e` for error handling
- Define variables at the top:
```bash
NAMESPACE=${STREAMING_NAMESPACE:-streaming}
FAILURES=0
```
- Use functions for repeated logic:
```bash
test_result() {
  local test_name=$1
  local result=$2
  if [[ $result -eq 0 ]]; then
    echo "✓ PASS: $test_name"
  else
    echo "✗ FAIL: $test_name"
    ((FAILURES++))
  fi
}
```
- Use meaningful exit codes
- Include clear output messages

## Documentation Conventions

**File Naming:**
- README.md for each version directory
- Include date in markdown filenames: `2025-03-22-postgres-cdc-risingwave-iceberg.md`

**Content Structure:**
- Architecture diagrams with ASCII art
- Quick start instructions with code blocks
- Clear component descriptions
- Environment-specific presets
- Testing procedures

## Configuration Conventions

**YAML Files:**
- Use descriptive filenames: `values-performance.yaml`, `values-minimal.yaml`
- Structure with clear sections
- Use comments with `#`
- Follow Helm chart conventions

**Environment Variables:**
- Use consistent naming: `SPANNER_EMULATOR_HOST`, `FLINK_STATE_BACKEND`
- Provide defaults with `${VAR:-default}`
- Document required variables

## Error Handling Patterns

### Python
- Handle specific exceptions first
- Provide fallback mechanisms
- Use meaningful error messages

### Java/Scala
- Use proper exception hierarchy
- Log with context
- Use SLF4J facade

### SQL
- Use `IF NOT EXISTS` for idempotency
- Handle constraints properly
- Add comments for complex operations

### Shell Scripts
- Exit on error with `set -e`
- Use meaningful exit codes
- Provide clear error messages

## Testing Conventions

### Integration Tests
- Use descriptive names: `connectivity-test.sh`
- Test actual connectivity between components
- Use kubectl for Kubernetes integration
- Include clear success/failure indicators

### SQL Testing
- Use `INSERT INTO` for sample data
- Include constraints and indexes
- Use realistic data patterns

---

*Convention analysis: 2026-03-22*
```