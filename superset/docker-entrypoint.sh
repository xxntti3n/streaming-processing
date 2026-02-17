#!/bin/bash
set -e
export SUPERSET_PORT=${SUPERSET_PORT:-8088}

# Init Superset DB and admin (idempotent)
superset db upgrade
superset fab create-admin \
  --username "${ADMIN_USERNAME:-admin}" \
  --firstname "${ADMIN_FIRST_NAME:-Admin}" \
  --lastname "${ADMIN_LAST_NAME:-User}" \
  --email "${ADMIN_EMAIL:-admin@example.com}" \
  --password "${ADMIN_PASSWORD:-admin}" 2>/dev/null || true
superset init

# Pre-add Trino Iceberg database so admin can use it without "add database" permission issues
python /app/add_trino_db.py 2>/dev/null || true

# Start gunicorn bound to all interfaces so host can reach it
exec gunicorn \
  --bind "0.0.0.0:${SUPERSET_PORT}" \
  --workers 2 \
  --threads 4 \
  --timeout 120 \
  --limit-request-line 0 \
  --limit-request-field_size 0 \
  "superset.app:create_app()"
