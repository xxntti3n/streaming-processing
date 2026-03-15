# v1 Refactor Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify v1 folder by removing empty Helm wrapper charts and using external Bitnami charts directly through a single umbrella chart.

**Architecture:** Single umbrella chart (`streaming-stack`) that depends on external Bitnami charts (mysql, minio, kafka) instead of local empty wrapper charts.

**Tech Stack:** Helm 3, Bitnami charts, Kubernetes, bash scripts

---

## File Structure

**Files to be deleted:**
- `helm/mysql/` - Empty wrapper chart
- `helm/minio/` - Empty wrapper chart
- `helm/kafka/` - Empty wrapper chart
- `helm/lakekeeper/` - Empty wrapper chart
- `helm/spark/` - Empty wrapper chart
- `helm/superset/` - Empty wrapper chart
- `.archive/` - Archived original files

**Files to be created:**
- `helm/streaming-stack/Chart.yaml` - Replace with external dependencies

**Files to be modified:**
- `helm/streaming-stack/values.yaml` - Update for Bitnami structure
- `helm/streaming-stack/values-minimal.yaml` - Update for Bitnami structure
- `helm/streaming-stack/values-default.yaml` - Update for Bitnami structure
- `helm/streaming-stack/values-performance.yaml` - Update for Bitnami structure
- `README.md` - Update to reflect simplified structure

**Files to be verified/kept:**
- `config/resources.yaml` - Keep as-is
- `scripts/*` - Keep as-is
- `spark-jobs/*` - Keep as-is
- `tests/*` - Keep as-is
- `docs/*` - Keep as-is
- `.gitignore` - Already correct

---

## Chunk 1: Delete Empty Wrapper Charts

### Task 1: Delete Helm Wrapper Charts

**Files:**
- Delete: `helm/mysql/`
- Delete: `helm/minio/`
- Delete: `helm/kafka/`
- Delete: `helm/lakekeeper/`
- Delete: `helm/spark/`
- Delete: `helm/superset/`

- [ ] **Step 1: Verify wrapper charts are empty (no templates)**

```bash
for dir in mysql minio kafka lakekeeper spark superset; do
  echo "=== Checking helm/$dir/ ==="
  ls -la helm/$dir/ 2>/dev/null || echo "Directory does not exist"
  if [ -d "helm/$dir/templates" ]; then
    echo "  WARNING: has templates/ directory"
    ls helm/$dir/templates/ 2>/dev/null
  fi
done
```

Expected: All directories have only `Chart.yaml` and `values.yaml`, no `templates/`

- [ ] **Step 2: Delete wrapper chart directories**

```bash
git rm -r helm/mysql/ helm/minio/ helm/kafka/ helm/lakekeeper/ helm/spark/ helm/superset/
```

Expected: Output showing each directory removed

- [ ] **Step 3: Verify deletion**

```bash
ls -la helm/
```

Expected: Only `streaming-stack/` directory remains

### Task 2: Delete Archive Directory

**Files:**
- Delete: `.archive/`

- [ ] **Step 1: Check archive contents**

```bash
ls -la .archive/v1-original/
```

Expected: Lists old files (docker-compose.yml, Dockerfiles, etc.)

- [ ] **Step 2: Delete archive directory**

```bash
git rm -r .archive/
```

Expected: Archive directory removed

- [ ] **Step 3: Verify deletion**

```bash
ls -la | grep archive || echo "No archive directory"
```

Expected: No archive directory found

### Task 3: Commit Chart Deletions

- [ ] **Step 1: Check git status**

```bash
git status --short
```

Expected: Shows deletions for all wrapper charts and archive

- [ ] **Step 2: Commit deletions**

```bash
git commit -m "refactor: remove empty Helm wrapper charts and archive

- Remove mysql/, minio/, kafka/, lakekeeper/, spark/, superset/ wrappers
- Remove .archive/ directory with original v1 files
- These will be replaced by external Bitnami chart dependencies"
```

Expected: Commit created with message

---

## Chunk 2: Update Umbrella Chart Dependencies

### Task 4: Rewrite streaming-stack Chart.yaml

**Files:**
- Modify: `helm/streaming-stack/Chart.yaml`

- [ ] **Step 1: Backup current Chart.yaml**

```bash
cp helm/streaming-stack/Chart.yaml helm/streaming-stack/Chart.yaml.backup
```

- [ ] **Step 2: Write new Chart.yaml with external dependencies**

Write to `helm/streaming-stack/Chart.yaml`:

```yaml
apiVersion: v2
name: streaming-stack
description: Umbrella chart for streaming processing with Spark
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  # MySQL from Bitnami
  - name: mysql
    version: 12.x.x
    repository: https://charts.bitnami.com/bitnami
    condition: mysql.enabled
  # MinIO from Bitnami
  - name: minio
    version: 14.x.x
    repository: https://charts.bitnami.com/bitnami
    condition: minio.enabled
  # Kafka from Bitnami (Kraft mode, no Zookeeper)
  - name: kafka
    version: 30.x.x
    repository: https://charts.bitnami.com/bitnami
    condition: kafka.enabled
```

- [ ] **Step 3: Verify Chart.yaml syntax**

```bash
helm lint helm/streaming-stack/
```

Expected: No errors, possibly a warning about missing icon

- [ ] **Step 4: Remove backup**

```bash
rm helm/streaming-stack/Chart.yaml.backup
```

### Task 5: Update Helm Dependencies

- [ ] **Step 1: Remove old downloaded charts**

```bash
rm -rf helm/streaming-stack/charts/
```

- [ ] **Step 2: Update Helm dependencies**

```bash
cd helm/streaming-stack && helm dependency update && cd ../..
```

Expected: Output showing 3 charts downloaded (mysql, minio, kafka)

- [ ] **Step 3: Verify charts downloaded**

```bash
ls -la helm/streaming-stack/charts/
```

Expected: Shows mysql-*, minio-*, kafka-* directories

### Task 6: Commit Chart.yaml Update

- [ ] **Step 1: Check changes**

```bash
git diff helm/streaming-stack/Chart.yaml
```

Expected: Shows old local file:// dependencies replaced with https:// bitnami repos

- [ ] **Step 2: Stage and commit**

```bash
git add helm/streaming-stack/Chart.yaml
git commit -m "refactor: update streaming-stack to use external Bitnami charts

- Replace local wrapper dependencies with Bitnami chart repositories
- Add mysql (12.x.x), minio (14.x.x), kafka (30.x.x)
- Kafka will use Kraft mode (no Zookeeper dependency)"
```

Expected: Commit created

---

## Chunk 3: Update Values Files

### Task 7: Update values.yaml

**Files:**
- Modify: `helm/streaming-stack/values.yaml`

- [ ] **Step 1: Read current values.yaml**

```bash
cat helm/streaming-stack/values.yaml
```

Expected: Shows current values structure (may be incomplete)

- [ ] **Step 2: Write new values.yaml for Bitnami charts**

Write to `helm/streaming-stack/values.yaml`:

```yaml
# helm/streaming-stack/values.yaml
# Default values for streaming-stack umbrella chart

mysql:
  enabled: true
  auth:
    rootPassword: rootpw
    database: appdb
  primary:
    # Allow scheduling on control-plane nodes (for single-node clusters)
    tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi

minio:
  enabled: true
  auth:
    rootUser: minio
    rootPassword: minio123
  defaultBuckets: warehouse,iceberg
  # Allow scheduling on control-plane nodes
  tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule
  persistence:
    size: 10Gi
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

kafka:
  enabled: true
  # Use Kraft mode (no Zookeeper required)
  zookeeper:
    enabled: false
  controller:
    replicaCount: 1
    # Allow scheduling on control-plane nodes
    tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
    resources:
      requests:
        cpu: 300m
        memory: 512Mi
      limits:
        cpu: 700m
        memory: 1Gi
  broker:
    replicaCount: 1
    # Allow scheduling on control-plane nodes
    tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
    resources:
      requests:
        cpu: 300m
        memory: 512Mi
      limits:
        cpu: 700m
        memory: 1Gi
```

### Task 8: Update values-minimal.yaml

**Files:**
- Modify: `helm/streaming-stack/values-minimal.yaml`

- [ ] **Step 1: Write minimal values for resource-constrained environments**

Write to `helm/streaming-stack/values-minimal.yaml`:

```yaml
# helm/streaming-stack/values-minimal.yaml
# Minimal preset: Full stack, single executor, resource-constrained

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
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 300m
        memory: 256Mi

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
  persistence:
    size: 2Gi
  resources:
    requests:
      cpu: 100m
        memory: 128Mi
      limits:
        cpu: 300m
        memory: 256Mi

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
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
  broker:
    replicaCount: 1
    tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
```

- [ ] **Step 2: Verify YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('helm/streaming-stack/values-minimal.yaml'))" 2>/dev/null || echo "YAML syntax check failed"
```

Expected: No errors (or install PyYAML if needed)

### Task 9: Update values-default.yaml

**Files:**
- Modify: `helm/streaming-stack/values-default.yaml`

- [ ] **Step 1: Write default values for comfortable local development**

Write to `helm/streaming-stack/values-default.yaml`:

```yaml
# helm/streaming-stack/values-default.yaml
# Default preset: Comfortable local development

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
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi

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
  persistence:
    size: 5Gi
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

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
    resources:
      requests:
        cpu: 300m
        memory: 384Mi
      limits:
        cpu: 700m
        memory: 768Mi
  broker:
    replicaCount: 1
    tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
    resources:
      requests:
        cpu: 300m
        memory: 384Mi
      limits:
        cpu: 700m
        memory: 768Mi
```

### Task 10: Update values-performance.yaml

**Files:**
- Modify: `helm/streaming-stack/values-performance.yaml`

- [ ] **Step 1: Write performance values**

Write to `helm/streaming-stack/values-performance.yaml`:

```yaml
# helm/streaming-stack/values-performance.yaml
# Performance preset: Production-like testing with multiple replicas

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
    resources:
      requests:
        cpu: 500m
        memory: 768Mi
      limits:
        cpu: 1
        memory: 1.5Gi

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
  persistence:
    size: 20Gi
  resources:
    requests:
      cpu: 500m
      memory: 768Mi
    limits:
      cpu: 1
      memory: 1.5Gi

kafka:
  enabled: true
  zookeeper:
    enabled: false
  controller:
    replicaCount: 2
    tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
    resources:
      requests:
        cpu: 500m
        memory: 768Mi
      limits:
        cpu: 1
        memory: 1.5Gi
  broker:
    replicaCount: 2
    tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
    resources:
      requests:
        cpu: 500m
        memory: 768Mi
      limits:
        cpu: 1
        memory: 1.5Gi
```

### Task 11: Commit Values Updates

- [ ] **Step 1: Stage all values files**

```bash
git add helm/streaming-stack/values*.yaml
```

- [ ] **Step 2: Commit values updates**

```bash
git commit -m "refactor: update values files for Bitnami chart structure

- Align values.yaml with Bitnami mysql, minio, kafka charts
- Add control-plane tolerations for single-node clusters
- Configure Kafka Kraft mode (zookeeper.enabled: false)
- Update all presets: minimal, default, performance"
```

Expected: Commit created

---

## Chunk 4: Update Documentation

### Task 12: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read current README.md**

```bash
cat README.md
```

- [ ] **Step 2: Update README.md**

Write to `README.md`:

```markdown
# Streaming Processing v1

Real-time streaming processing using Apache Spark with continuous processing mode.

## Architecture

```
MySQL CDC → Kafka → Spark Streaming → Iceberg → Spark SQL → BI Tools
            (Continuous Mode)         (Object Storage)
```

## Quick Start

```bash
# 1. Check system capacity
./scripts/check-capacity.sh

# 2. Deploy with preset (minimal, default, performance)
./scripts/start.sh minimal

# 3. Verify deployment
./scripts/verify-stack.sh

# 4. Run integration tests
./scripts/test-integration.sh
```

## Project Structure

```
v1/
├── config/              # Resource presets for different environments
├── docs/                # Architecture, deployment, troubleshooting guides
├── helm/
│   └── streaming-stack/ # Umbrella Helm chart (uses Bitnami charts)
├── scripts/             # Deployment and verification scripts
├── spark-jobs/          # Scala streaming processor code
└── tests/               # E2E and integration tests
```

## Components

| Component | Chart | Description |
|-----------|-------|-------------|
| MySQL | bitnami/mysql | Source database with CDC enabled |
| MinIO | bitnami/minio | S3-compatible object storage for Iceberg |
| Kafka | bitnami/kafka | Event streaming platform (Kraft mode) |

## Presets

- **minimal** - Resource-constrained, 2Gi storage
- **default** - Comfortable local development, 5Gi storage
- **performance** - Production-like, 20Gi storage, multiple replicas

## Documentation

- [Architecture](docs/architecture.md)
- [Deployment Guide](docs/deployment-guide.md)
- [Troubleshooting](docs/troubleshooting.md)
```

- [ ] **Step 3: Verify README markdown**

```bash
head -50 README.md
```

Expected: New content visible

### Task 13: Commit Documentation Update

- [ ] **Step 1: Stage and commit README**

```bash
git add README.md
git commit -m "refactor: update README for simplified structure

- Document new umbrella chart approach using Bitnami charts
- Update project structure section
- Add component table with chart sources
- Clarify presets and their use cases"
```

Expected: Commit created

---

## Chunk 5: Final Cleanup and Verification

### Task 14: Clean Git State

- [ ] **Step 1: Check git status**

```bash
git status
```

Expected: Only untracked files in `helm/streaming-stack/charts/` (gitignored)

- [ ] **Step 2: Verify .gitignore covers charts/**

```bash
grep "helm.*/charts/" .gitignore || echo "Pattern not found"
```

Expected: Pattern exists (already in .gitignore)

- [ ] **Step 3: Verify no unexpected modifications**

```bash
git diff --name-only
```

Expected: Only expected files modified (README.md, Chart.yaml, values*)

### Task 15: Verify Deployment Script Works

- [ ] **Step 1: Test start.sh dry-run**

```bash
./scripts/start.sh --help 2>&1 | head -5 || true
```

Expected: Script exists and is executable

- [ ] **Step 2: Verify script can find streaming-stack chart**

```bash
ls -la helm/streaming-stack/Chart.yaml
```

Expected: Chart.yaml exists in streaming-stack/

- [ ] **Step 3: Verify Helm can lint the chart**

```bash
helm lint helm/streaming-stack/
```

Expected: Chart lints successfully (may have warnings about icon)

### Task 16: Final Verification

- [ ] **Step 1: List all remaining helm charts**

```bash
find helm -name "Chart.yaml" -type f
```

Expected: Only `helm/streaming-stack/Chart.yaml` exists

- [ ] **Step 2: Count total files changed**

```bash
git status --short | wc -l
```

Expected: Reasonable number of changes (not hundreds)

- [ ] **Step 3: Show final directory structure**

```bash
ls -la
ls -la helm/
ls -la helm/streaming-stack/
```

Expected: Clean structure with only `streaming-stack/` in `helm/`

### Task 17: Create Summary Commit

- [ ] **Step 1: Review all commits**

```bash
git log --oneline -5
```

- [ ] **Step 2: Create summary commit if needed**

```bash
# Only if there are any remaining uncommitted changes
git status --short && git commit -m "refactor: complete v1 cleanup

- All empty wrapper charts removed
- Umbrella chart updated to use Bitnami dependencies
- Values files aligned with Bitnami chart structure
- Documentation updated to reflect new structure"
```

---

## Testing Strategy

After completing all tasks:

1. **Verify chart dependencies**: `helm dependency update` should download 3 charts
2. **Verify chart lint**: `helm lint` should pass
3. **Verify deployment script**: `./scripts/start.sh minimal` should work (requires cluster)
4. **Verify git state**: `git status` should show only gitignored charts/ directory

## Rollback Plan

If something goes wrong:

```bash
# Reset to before refactor
git reset --hard <commit-before-refactor>

# Or restore specific files
git checkout HEAD~1 -- helm/
```
