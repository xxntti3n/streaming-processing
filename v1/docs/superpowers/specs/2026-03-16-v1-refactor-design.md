# v1 Refactor Design: Minimal Umbrella Chart

**Date:** 2026-03-16
**Status:** Approved
**Approach:** Minimal Umbrella (Approach 1)

## Overview

Simplify the v1 streaming processing folder by removing empty Helm wrapper charts and using external Bitnami charts directly through a single umbrella chart.

## Problem Statement

The v1 folder contains:
- Empty Helm wrapper charts (mysql/, minio/, kafka/, lakekeeper/, spark/, superset/) with no templates
- `streaming-stack/Chart.yaml` pointing to external repos but local wrappers still exist
- Confusion about which files are actively used vs. placeholders
- Mixed modification state in git

## Solution

### 1. Directory Structure

**Before:**
```
v1/
├── .archive/v1-original/
├── config/resources.yaml
├── docs/
├── helm/
│   ├── mysql/              # Empty wrapper
│   ├── minio/              # Empty wrapper
│   ├── kafka/              # Empty wrapper
│   ├── lakekeeper/         # Empty wrapper
│   ├── spark/              # Empty wrapper
│   ├── superset/           # Empty wrapper
│   └── streaming-stack/    # Umbrella
├── scripts/
├── spark-jobs/
└── tests/
```

**After:**
```
v1/
├── config/
│   └── resources.yaml
├── docs/
├── helm/
│   └── streaming-stack/     # Only umbrella chart
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-minimal.yaml
│       ├── values-default.yaml
│       ├── values-performance.yaml
│       └── charts/         # Downloaded deps (gitignored)
├── scripts/
├── spark-jobs/
├── tests/
├── .gitignore
└── README.md
```

### 2. Helm Dependencies

**streaming-stack/Chart.yaml:**
```yaml
apiVersion: v2
name: streaming-stack
description: Umbrella chart for streaming processing with Spark
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  - name: mysql
    version: 12.x.x
    repository: https://charts.bitnami.com/bitnami
    condition: mysql.enabled
  - name: minio
    version: 14.x.x
    repository: https://charts.bitnami.com/bitnami
    condition: minio.enabled
  - name: kafka
    version: 30.x.x
    repository: https://charts.bitnami.com/bitnami
    condition: kafka.enabled
```

**Notes:**
- Lakekeeper removed (no stable repo URL)
- Spark Operator removed (can be added later)
- Superset removed (can be added later)
- Kafka uses Kraft mode (no Zookeeper)

### 3. Values Structure

All `values-*.yaml` files follow Bitnami chart conventions:

```yaml
mysql:
  enabled: true
  auth:
    rootPassword: rootpw
    database: appdb
  primary:
    tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule

minio:
  enabled: true
  auth:
    rootUser: minio
    rootPassword: minio123
  defaultBuckets: warehouse,iceberg
  tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule

kafka:
  enabled: true
  zookeeper:
    enabled: false
  controller:
    replicaCount: 1
    tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
  broker:
    replicaCount: 1
    tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
```

### 4. Cleanup Actions

**Delete:**
- `helm/mysql/`
- `helm/minio/`
- `helm/kafka/`
- `helm/lakekeeper/`
- `helm/spark/`
- `helm/superset/`
- `.archive/`

**Modify:**
- `helm/streaming-stack/values-*.yaml` - Update for Bitnami structure
- `README.md` - Update documentation

**Keep unchanged:**
- `config/resources.yaml`
- `scripts/*`
- `spark-jobs/*`
- `tests/*`
- `docs/*`
- `.gitignore` (already correct)

### 5. Git Operations

```bash
# Remove staged changes to values-minimal.yaml
git restore --staged helm/streaming-stack/values-minimal.yaml

# Add deletions
git rm -r helm/mysql/ helm/minio/ helm/kafka/ helm/lakekeeper/ helm/spark/ helm/superset/ .archive/

# Add modified Chart.yaml
git add helm/streaming-stack/Chart.yaml

# Update values files and commit
git add helm/streaming-stack/values-*.yaml
git commit -m "refactor: simplify v1 to minimal umbrella chart

- Remove empty wrapper charts (mysql, minio, kafka, lakekeeper, spark, superset)
- Update streaming-stack to use external Bitnami charts directly
- Add control-plane tolerations for single-node clusters
- Use Kafka Kraft mode (no Zookeeper)
- Keep spark-jobs, scripts, tests, docs unchanged"
```

## Success Criteria

1. Only `helm/streaming-stack/` remains in `helm/`
2. `helm dependency update` successfully downloads external charts
3. `./scripts/start.sh minimal` successfully deploys
4. No untracked or modified files in git status
5. README.md reflects simplified structure
