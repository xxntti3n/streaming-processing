#!/bin/sh
# Sleep to wait for MinIO to be ready
sleep 5

# Configure mc alias (use default alias 'local' for MinIO)
mc alias set local http://minio:9000 minio minio123

# Iceberg warehouse: s3://iceberg/warehouse
mc mb local/iceberg --ignore-existing
mc mb local/warehouse --ignore-existing

mc ls local
echo "MinIO bucket setup completed"
