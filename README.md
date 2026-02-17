# End-to-end streaming: MySQL CDC → Flink → Iceberg → Trino

Streaming pipeline that reads CDC from MySQL, **joins and aggregates** two tables (products + sales) in Flink, and writes one result table to Iceberg. Query with Trino.

## Architecture

- **MySQL**: source DB with `appdb.products` and `appdb.sales`; binlog CDC enabled.
- **Flink**: single streaming job — MySQL CDC (2 tables) → join → aggregate by product → **one Iceberg table** `demo.sales_by_product`.
- **Iceberg**: catalog in MySQL (`iceberg_catalog`), data in MinIO (`s3://iceberg/warehouse`).
- **Trino**: query `iceberg.demo.sales_by_product` (and any other Iceberg tables).

## Prerequisites

- Docker and Docker Compose
- (Optional) Trino Iceberg JDBC needs MySQL driver:  
  `mkdir -p trino/lib && curl -L -o trino/lib/mysql-connector-j-8.4.0.jar https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.4.0/mysql-connector-j-8.4.0.jar`

## Deploy

```bash
# Build and start (first run can take 5–10 min for image pulls)
docker compose up -d --build
# or: docker-compose up -d --build

# Create MinIO bucket (if mc service already exited: run once)
docker compose run --rm mc

# Wait for Flink (e.g. 30s), then submit the streaming job
./submit-flink-job.sh
```

## Verify

```bash
./verify-stack.sh
```

- **Flink UI**: http://localhost:8081  
- **Trino**: http://localhost:8080  
- **MinIO**: http://localhost:9001 (minio / minio123)  
- **Superset**: http://localhost:8088 (admin / admin)

### Query result table in Trino

```bash
docker exec streaming-trino trino --execute "SELECT * FROM iceberg.demo.sales_by_product"
```

### Insert more data (streaming will update aggregates)

```bash
docker exec streaming-mysql mysql -u root -prootpw -e "INSERT INTO appdb.sales (product_id, qty, price, sale_ts) VALUES (1, 2, 9.99, NOW());"
```

Then query again: aggregates in `sales_by_product` update via the Flink job.

## Superset: chart Iceberg data via Trino

The **Trino Iceberg** database (`trino://admin@trino:8080/iceberg`) is added automatically at startup. You do not need to add it in the UI.

1. Open **Superset**: http://localhost:8088 and log in (admin / admin).
2. **Add dataset**: Data → Datasets → + Dataset.  
   - Database: **Trino Iceberg**, Schema: `demo`, Table: `sales_by_product` → Save.
3. **Create chart**: Charts → + Chart.  
   - Choose the `sales_by_product` dataset, pick a chart type (e.g. Bar Chart).  
   - **Metrics**: e.g. `total_revenue` (SUM) or `total_qty` (SUM).  
   - **Dimensions**: e.g. `product_sku` or `product_name`.  
   - Run query and Save.

You can also use **SQL Lab** and select database **Trino Iceberg** to run ad‑hoc SQL (e.g. `SELECT * FROM demo.sales_by_product`). Charts use live Iceberg data via Trino.

## Job definition

- **Single job**: `jobs/cdc_join_aggregate_to_iceberg.sql`
  - CDC sources: `mysql_products_stream`, `mysql_sales_stream`
  - Result table: `lake.demo.sales_by_product` (product_id, product_sku, product_name, total_qty, total_revenue, sale_count, last_sale_ts)
  - Upsert by `product_id` so streaming aggregation updates the same row.
