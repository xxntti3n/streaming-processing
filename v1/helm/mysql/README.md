# MySQL Chart

This is a **values-only** Helm chart meant to be consumed as a dependency of the `streaming-stack` umbrella chart.

## Usage

This chart should NOT be installed directly. Instead, deploy via:

```bash
helm install streaming-stack ./helm/streaming-stack
```

## Configuration

This chart configures the upstream Bitnami MySQL chart with:
- CDC enabled (binary log, ROW format, GTID mode)
- Sample data (products and sales tables)
- Development resource defaults

**Security Note:** The default credentials (`rootpw`) are for development only. Override for production:

```bash
helm upgrade streaming-stack ./helm/streaming-stack \
  --set mysql.auth.rootPassword=$MYSQL_ROOT_PASSWORD
```

## Database Schema

- `appdb.products` - Product catalog
- `appdb.sales` - Sales transactions with FK to products
- `iceberg_catalog` - For Iceberg JDBC catalog (optional)
