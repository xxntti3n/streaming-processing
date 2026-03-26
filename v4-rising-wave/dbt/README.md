# dbt-risingwave for CDC Pipeline

This directory contains the dbt project for managing transformations on the RisingWave CDC data.

## Quick Start

### Option 1: Local Installation

```bash
# Install Python dependencies
pip install -r dbt/requirements.txt

# Test connection to RisingWave
./scripts/dbt.sh debug

# Run all models
./scripts/dbt.sh run

# Run tests
./scripts/dbt.sh test
```

### Option 2: Docker

```bash
# Build dbt Docker image
docker build -t rw-cdc-dbt dbt/

# Run dbt commands
docker run --rm --network v4-rising-wave_default \
  -v $(pwd)/dbt:/usr/src/app \
  rw-cdc-dbt debug
```

## Project Structure

```
dbt/
├── dbt_project.yml     # Project configuration
├── packages.yml        # Dependencies (dbt-utils)
├── profiles.yml        # RisingWave connection profile
├── requirements.txt    # Python dependencies
├── Dockerfile          # Docker image for dbt
├── models/
│   ├── staging/        # Raw CDC -> Staging models
│   │   ├── customers/
│   │   └── orders/
│   ├── intermediate/   # Joins and transformations
│   └── marts/          # Business-ready aggregates
│       ├── analytics/  # Analytics mart
│       └── finance/    # Finance mart
├── tests/              # Data tests
├── macros/             # Custom macros
└── seeds/              # Static seed data
```

## Available Models

### Staging Layer
| Model | Description | Source |
|-------|-------------|--------|
| `stg_customers` | Clean customer data | `customers_cdc` |
| `stg_orders` | Clean order data | `orders_cdc` |

### Intermediate Layer
| Model | Description |
|-------|-------------|
| `int_customer_orders` | Customers joined with orders |

### Mart Layer
| Model | Description |
|-------|-------------|
| `fct_customer_order_summary` | Per-customer aggregates |
| `fct_high_value_orders` | Orders ≥ $100 |
| `dim_customer_spending_tier` | Customer tier classification |
| `fct_order_status_dashboard` | Status breakdown |
| `fct_daily_order_metrics` | Daily metrics |

## dbt CLI Commands

```bash
# Test connection
./scripts/dbt.sh debug

# List all models
./scripts/dbt.sh list

# Run all models
./scripts/dbt.sh run

# Run specific model
./scripts/dbt.sh run stg_customers

# Run with selector (e.g., only marts)
./scripts/dbt.sh run +marts

# Full refresh
./scripts/dbt.sh run-full

# Run tests
./scripts/dbt.sh test

# Compile (show generated SQL)
./scripts/dbt.sh compile

# Show model details
./scripts/dbt.sh show fct_customer_order_summary

# Generate documentation
./scripts/dbt.sh generate

# Serve documentation site
./scripts/dbt.sh docs
```

## Model Selection Syntax

```bash
# Select specific model
./scripts/dbt.sh run stg_customers

# Select model and all children
./scripts/dbt.sh run +stg_customers

# Select model and all parents
./scripts/dbt.sh run +fct_customer_order_summary+

# Select all models in a directory
./scripts/dbt.sh run staging

# Select by tag
./scripts/dbt.sh run --select tag:tier1
```

## Testing

```bash
# Run all tests
./scripts/dbt.sh test

# Run specific test
./scripts/dbt.sh test unique_stg_customers_customer_id

# Run tests for specific model
./scripts/dbt.sh test --models stg_customers
```

## Documentation

After running `dbt docs generate`, view the documentation:

```bash
./scripts/dbt.sh docs
# Open http://localhost:8080
```

## Configuration

### Connection Profile (profiles.yml)

```yaml
risingwave_cdc:
  outputs:
    dev:
      type: risingwave
      host: risingwave
      port: 4566
      user: root
      pass: ""
      dbname: dev
      schema: public
  target: dev
```

### Model Configuration

```sql
{{ config(
    materialized='materialized_view',
    schema='marts',
    indexes=[
        {'columns': ['customer_id'], 'include': ['customer_name']}
    ]
) }}
```

## Migration from SQL Scripts

The transformations previously in `sql/04-streaming-transforms.sql` are now managed by dbt:

| Old Name | New dbt Model |
|----------|---------------|
| `customer_order_summary` | `fct_customer_order_summary` |
| `high_value_orders` | `fct_high_value_orders` |
| `order_status_dashboard` | `fct_order_status_dashboard` |
| `daily_order_metrics` | `fct_daily_order_metrics` |
| `customer_spending_tier` | `dim_customer_spending_tier` |
| `recent_orders` | *(not yet migrated)* |

## Benefits of Using dbt

- ✅ **Version Control**: All transformations in Git
- ✅ **Testing**: Data tests and schema tests
- ✅ **Documentation**: Auto-generated from code
- ✅ **Modularity**: Reusable components
- ✅ **Team Collaboration**: Standard workflows
- ✅ **Lineage**: Track data flow
- ✅ **CI/CD Ready**: Easy to integrate

## References

- [dbt-risingwave GitHub](https://github.com/risingwavelabs/dbt-risingwave)
- [RisingWave dbt Documentation](https://docs.risingwave.com/integrations/other/dbt)
- [dbt Documentation](https://docs.getdbt.com/)
