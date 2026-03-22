# Technology Stack

**Analysis Date:** 2026-03-22

## Languages

**Primary:**
- SQL - Used for database schema definition, CDC configuration, and stream processing logic

## Runtime

**Environment:**
- Docker Compose - Container orchestration
- Docker - Container runtime

**Package Manager:**
- None - No application code, declarative configuration only
- Lockfile: Not applicable

## Frameworks

**Core:**
- RisingWave v2.7.1 - Stream processing engine
- PostgreSQL 17-alpine - Source database

**Testing:**
- No testing framework detected - Manual verification only

**Build/Dev:**
- Docker Compose - Development environment orchestration

## Key Dependencies

**Critical:**
- RisingWave - Core stream processing engine with PostgreSQL CDC and Iceberg sinks
- PostgreSQL - Source database with logical replication

**Infrastructure:**
- MinIO - S3-compatible object storage
- MinIO Client (mc) - CLI utility for bucket initialization

## Configuration

**Environment:**
- Environment variables via `.env` file
- Key configs required: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `RW_IMAGE`, `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`

**Build:**
- No build configuration files (images are pre-built)
- Docker Compose for service orchestration

## Platform Requirements

**Development:**
- Docker and Docker Compose
- ~6GB memory total (4GB for RisingWave, 512MB each for PostgreSQL and MinIO)
- 16GB development machine recommended

**Production:**
- Kubernetes deployment possible but not implemented
- Resource requirements scale with data volume and processing needs

---

*Stack analysis: 2026-03-22*
```