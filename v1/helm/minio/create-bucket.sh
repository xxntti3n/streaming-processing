#!/bin/sh
# helm/minio/create-bucket.sh
# Wait for MinIO to be ready
sleep 5

# Configure mc alias
mc alias set local http://minio:9000 minio minio123

# Create buckets for Iceberg
mc mb local/iceberg --ignore-existing
mc mb local/warehouse --ignore-existing

# Verify
mc ls local/

echo "MinIO bucket setup completed"
