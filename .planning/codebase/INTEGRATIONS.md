# External Integrations

**Analysis Date:** 2026-03-22

## APIs & External Services

**Database:**
- PostgreSQL - Source database with CDC enabled
  - Connection: `postgresql://postgres:postgres@postgres:5432/mydb`
  - CDC Connector: Built-in RisingWave PostgreSQL CDC

**Storage:**
- MinIO - S3-compatible object storage
  - Connection: `http://minio:9301` (S3 API), `http://localhost:9400` (Console)
  - SDK/Client: MinIO CLI (`mc`) for initialization
  - Auth: `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` environment variables

## Data Storage

**Databases:**
- PostgreSQL 17 - Source database with logical replication
  - Connection: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` env vars
  - Client: Built-in PostgreSQL CDC connector in RisingWave

**File Storage:**
- MinIO - Primary storage for Iceberg tables and RisingWave state
  - Connection: Built-in S3 client in RisingWave
  - Buckets: `hummock001` (state), `iceberg-data` (tables)

**Caching:**
- Not detected - Direct write-through to MinIO

## Authentication & Identity

**Auth Provider:**
- Custom - Simple environment variable authentication
  - Implementation: No formal auth system, hardcoded credentials in development

## Monitoring & Observability

**Error Tracking:**
- Not detected - No error tracking service implemented

**Logs:**
- Container logs - Docker Compose logs
- Built-in dashboard - RisingWave UI at http://localhost:5691

## CI/CD & Deployment

**Hosting:**
- Local Docker Compose - Development deployment
- No production deployment pipeline detected

**CI Pipeline:**
- Not detected - Manual deployment only

## Environment Configuration

**Required env vars:**
- `POSTGRES_USER` - PostgreSQL username
- `POSTGRES_PASSWORD` - PostgreSQL password
- `POSTGRES_DB` - PostgreSQL database name
- `RW_IMAGE` - RisingWave Docker image tag
- `MINIO_ROOT_USER` - MinIO access key
- `MINIO_ROOT_PASSWORD` - MinIO secret key
- `RW_SECRET_STORE_PRIVATE_KEY_HEX` - RisingWave secret management key

**Secrets location:**
- `.env` file in project root

## Webhooks & Callbacks

**Incoming:**
- Not detected - No webhook endpoints

**Outgoing:**
- Not detected - No outgoing webhooks

---

*Integration audit: 2026-03-22*
```