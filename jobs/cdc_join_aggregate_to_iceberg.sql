SET 'execution.runtime-mode' = 'streaming';
SET 'execution.checkpointing.interval' = '60s';
SET 'table.exec.state.ttl' = '86400000';

CREATE CATALOG lake WITH ('type' = 'iceberg', 'catalog-impl' = 'org.apache.iceberg.jdbc.JdbcCatalog', 'uri' = 'jdbc:mysql://mysql:3306/iceberg_catalog', 'jdbc.user' = 'root', 'jdbc.password' = 'rootpw', 'warehouse' = 's3://iceberg/warehouse', 'io-impl' = 'org.apache.iceberg.aws.s3.S3FileIO', 's3.endpoint' = 'http://minio:9000', 's3.path-style-access' = 'true', 's3.access-key-id' = 'minio', 's3.secret-access-key' = 'minio123', 'client.region' = 'us-east-1');

USE CATALOG default_catalog;

CREATE TEMPORARY TABLE mysql_products_stream (id INT, sku STRING, name STRING, PRIMARY KEY (id) NOT ENFORCED) WITH ('connector' = 'mysql-cdc', 'hostname' = 'mysql', 'port' = '3306', 'username' = 'root', 'password' = 'rootpw', 'database-name' = 'appdb', 'table-name' = 'products', 'scan.incremental.snapshot.enabled' = 'true', 'scan.startup.mode' = 'initial');

CREATE TEMPORARY TABLE mysql_sales_stream (id BIGINT, product_id INT, qty INT, price DECIMAL(10,2), sale_ts TIMESTAMP(3), PRIMARY KEY (id) NOT ENFORCED) WITH ('connector' = 'mysql-cdc', 'hostname' = 'mysql', 'port' = '3306', 'username' = 'root', 'password' = 'rootpw', 'database-name' = 'appdb', 'table-name' = 'sales', 'scan.incremental.snapshot.enabled' = 'true', 'scan.startup.mode' = 'initial');

USE CATALOG lake;
CREATE DATABASE demo;
USE demo;

CREATE TABLE sales_by_product (product_id INT, product_sku STRING, product_name STRING, total_qty BIGINT, total_revenue DECIMAL(15,2), sale_count BIGINT, last_sale_ts TIMESTAMP(3), PRIMARY KEY (product_id) NOT ENFORCED) WITH ('format-version' = '2', 'write.upsert.enabled' = 'true');

USE CATALOG default_catalog;

INSERT INTO lake.demo.sales_by_product SELECT p.id AS product_id, p.sku AS product_sku, p.name AS product_name, SUM(s.qty) AS total_qty, SUM(s.qty * s.price) AS total_revenue, COUNT(*) AS sale_count, MAX(s.sale_ts) AS last_sale_ts FROM mysql_sales_stream s JOIN mysql_products_stream p ON s.product_id = p.id GROUP BY p.id, p.sku, p.name;
