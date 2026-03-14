# Spark Continuous Streaming Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure v1 folder to use unified Spark architecture with continuous processing, Lakekeeper catalog, and Kubernetes-first deployment

**Architecture:** Replace Flink + Trino with Spark (streaming + SQL), add Kafka for CDC buffering, Lakekeeper for Iceberg catalog, deploy via Helm charts

**Tech Stack:** Spark Structured Streaming (continuous mode), Kafka, Debezium, Lakekeeper, MinIO, Helm, Kubernetes

---

## File Structure Overview

```
v1/
├── helm/
│   ├── streaming-stack/           # Umbrella chart (NEW)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values-barebones.yaml  # Resource presets
│   │   ├── values-minimal.yaml
│   │   ├── values-default.yaml
│   │   └── values-performance.yaml
│   ├── spark/                     # Spark Operator chart (NEW)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── jobs/
│   │       ├── streaming-job.yaml
│   │       └── thrift-server.yaml
│   ├── kafka/                     # Kafka chart (NEW)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── connect/
│   │       └── debezium-mysql.json
│   ├── mysql/                     # MySQL chart (NEW - migrate from v1)
│   │   ├── Chart.yaml
│   │   └── values.yaml
│   ├── minio/                     # MinIO chart (NEW - migrate from v1)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── create-bucket.sh
│   ├── lakekeeper/                # Lakekeeper chart (NEW)
│   │   ├── Chart.yaml
│   │   └── values.yaml
│   └── superset/                  # Superset chart (NEW - migrate from v1)
│       ├── Chart.yaml
│       └── values.yaml
├── spark-jobs/                    # Spark application code (NEW)
│   └── streaming-processor/
│       ├── build.sbt
│       └── src/main/scala/
│           └── streaming/
│               └── CDCContinuousProcessor.scala
├── scripts/                       # Utility scripts (NEW)
│   ├── start.sh
│   ├── stop.sh
│   ├── check-capacity.sh
│   ├── verify-stack.sh
│   └── test-integration.sh
├── sql/                           # EXISTING - keep as-is
│   └── init.sql
├── config/                        # Shared configuration (NEW)
│   └── resources.yaml
├── tests/                         # Tests (NEW)
│   ├── e2e/
│   └── integration/
└── docs/                          # Documentation
    └── architecture.md
```

---

## Chunk 1: Base Folder Structure and Configuration

### Task 1: Create Directory Structure

**Files:**
- Create: `config/`
- Create: `helm/`
- Create: `spark-jobs/`
- Create: `scripts/`
- Create: `tests/e2e/`
- Create: `tests/integration/`
- Create: `docs/`

- [ ] **Step 1: Create base directories**

```bash
cd /Users/xxntti3n/Desktop/nttien/streaming-processing/v1
mkdir -p config helm spark-jobs/scripts tests/{e2e,integration}
```

- [ ] **Step 2: Create .gitignore entries for new directories**

Edit `.gitignore` - add:
```
# Spark builds
spark-jobs/*/target/
spark-jobs/*/project/target/
spark-jobs/*/project/project/

# Kubernetes
helm/*/charts/
*.kubeconfig
```

- [ ] **Step 3: Commit directory structure**

```bash
git add config/ helm/ spark-jobs/ scripts/ tests/ .gitignore
git commit -m "feat: add base directory structure for Spark restructure"
```

---

### Task 2: Create Resource Presets Configuration

**Files:**
- Create: `config/resources.yaml`

- [ ] **Step 1: Write resource presets configuration**

```yaml
# config/resources.yaml
# Resource presets for different environments and use cases

presets:
  barebones:
    description: "CDC + Streaming only (no BI, minimal storage)"
    total:
      cpu: "1.5"
      memory: "2GB"
    spark:
      executorInstances: 1
      executorMemory: "512m"
      executorCores: "1"
      driverMemory: "512m"
      driverCores: "1"
      sqlServerEnabled: false
    kafka:
      replicas: 1
      storage: "1Gi"
      resources:
        requests:
          cpu: "200m"
          memory: "256Mi"
        limits:
          cpu: "500m"
          memory: "512Mi"
    zookeeper:
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "200m"
          memory: "256Mi"
    kafkaConnect:
      resources:
        requests:
          cpu: "100m"
          memory: "192Mi"
        limits:
          cpu: "300m"
          memory: "384Mi"
    mysql:
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "300m"
          memory: "256Mi"
    lakekeeper:
      resources:
        requests:
          cpu: "50m"
          memory: "128Mi"
        limits:
          cpu: "150m"
          memory: "256Mi"
    minio:
      storage: "2Gi"
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "300m"
          memory: "256Mi"
    superset:
      enabled: false

  minimal:
    description: "Full stack, single executor"
    total:
      cpu: "2.4"
      memory: "4.5GB"
    spark:
      executorInstances: 1
      executorMemory: "1g"
      executorCores: "1"
      driverMemory: "1g"
      driverCores: "1"
      sqlServerEnabled: true
    kafka:
      replicas: 1
      storage: "2Gi"
      resources:
        requests:
          cpu: "300m"
          memory: "512Mi"
        limits:
          cpu: "800m"
          memory: "1Gi"
    zookeeper:
      resources:
        requests:
          cpu: "100m"
          memory: "256Mi"
        limits:
          cpu: "200m"
          memory: "512Mi"
    kafkaConnect:
      resources:
        requests:
          cpu: "200m"
          memory: "384Mi"
        limits:
          cpu: "500m"
          memory: "768Mi"
    mysql:
      resources:
        requests:
          cpu: "200m"
          memory: "256Mi"
        limits:
          cpu: "500m"
          memory: "512Mi"
    lakekeeper:
      resources:
        requests:
          cpu: "100m"
          memory: "256Mi"
        limits:
          cpu: "300m"
          memory: "512Mi"
    minio:
      storage: "5Gi"
      resources:
        requests:
          cpu: "200m"
          memory: "256Mi"
        limits:
          cpu: "500m"
          memory: "512Mi"
    superset:
      enabled: true
      resources:
        requests:
          cpu: "300m"
          memory: "512Mi"
        limits:
          cpu: "800m"
          memory: "1Gi"

  default:
    description: "Comfortable local development"
    total:
      cpu: "3.5"
      memory: "6GB"
    spark:
      executorInstances: 1
      executorMemory: "2g"
      executorCores: "2"
      driverMemory: "2g"
      driverCores: "1"
      sqlServerEnabled: true
    kafka:
      replicas: 1
      storage: "5Gi"
      resources:
        requests:
          cpu: "500m"
          memory: "768Mi"
        limits:
          cpu: "1"
          memory: "1.5Gi"
    zookeeper:
      resources:
        requests:
          cpu: "200m"
          memory: "384Mi"
        limits:
          cpu: "400m"
          memory: "768Mi"
    kafkaConnect:
      resources:
        requests:
          cpu: "300m"
          memory: "512Mi"
        limits:
          cpu: "700m"
          memory: "1Gi"
    mysql:
      resources:
        requests:
          cpu: "300m"
          memory: "384Mi"
        limits:
          cpu: "700m"
          memory: "768Mi"
    lakekeeper:
      resources:
        requests:
          cpu: "200m"
          memory: "384Mi"
        limits:
          cpu: "500m"
          memory: "768Mi"
    minio:
      storage: "10Gi"
      resources:
        requests:
          cpu: "300m"
          memory: "384Mi"
        limits:
          cpu: "700m"
          memory: "768Mi"
    superset:
      enabled: true
      resources:
        requests:
          cpu: "500m"
          memory: "768Mi"
        limits:
          cpu: "1"
          memory: "1.5Gi"

  performance:
    description: "Production-like testing"
    total:
      cpu: "6+"
      memory: "10GB+"
    spark:
      executorInstances: 2
      executorMemory: "2g"
      executorCores: "2"
      driverMemory: "2g"
      driverCores: "1"
      sqlServerEnabled: true
    kafka:
      replicas: 2
      storage: "10Gi"
      resources:
        requests:
          cpu: "1"
          memory: "1Gi"
        limits:
          cpu: "2"
          memory: "2Gi"
    zookeeper:
      resources:
        requests:
          cpu: "300m"
          memory: "512Mi"
        limits:
          cpu: "600m"
          memory: "1Gi"
    kafkaConnect:
      resources:
        requests:
          cpu: "500m"
          memory: "768Mi"
        limits:
          cpu: "1"
          memory: "1.5Gi"
    mysql:
      resources:
        requests:
          cpu: "500m"
          memory: "768Mi"
        limits:
          cpu: "1"
          memory: "1.5Gi"
    lakekeeper:
      resources:
        requests:
          cpu: "300m"
          memory: "512Mi"
        limits:
          cpu: "700m"
          memory: "1Gi"
    minio:
      storage: "20Gi"
      resources:
        requests:
          cpu: "500m"
          memory: "768Mi"
        limits:
          cpu: "1"
          memory: "1.5Gi"
    superset:
      enabled: true
      resources:
        requests:
          cpu: "700m"
          memory: "1Gi"
        limits:
          cpu: "1.5"
          memory: "2Gi"
```

- [ ] **Step 2: Verify YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('config/resources.yaml'))"
echo "YAML syntax valid"
```

Expected: "YAML syntax valid"

- [ ] **Step 3: Commit resource presets**

```bash
git add config/resources.yaml
git commit -m "feat: add resource presets for different deployment modes"
```

---

## Chunk 2: Utility Scripts

### Task 3: Create System Capacity Check Script

**Files:**
- Create: `scripts/check-capacity.sh`

- [ ] **Step 1: Write capacity check script**

```bash
#!/bin/bash
# scripts/check-capacity.sh
# Check system resources and recommend preset

echo "=== System Resource Check ==="
echo ""

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  TOTAL_CPUS=$(sysctl -n hw.logicalcpu)
  TOTAL_MEM_BYTES=$(sysctl -n hw.memsize)
  TOTAL_MEM_GB=$(echo "scale=1; $TOTAL_MEM_BYTES / 1024 / 1024 / 1024" | bc)
elif [[ -f /proc/meminfo ]]; then
  # Linux
  TOTAL_CPUS=$(nproc)
  TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  TOTAL_MEM_GB=$(echo "scale=1; $TOTAL_MEM_KB / 1024 / 1024" | bc)
else
  echo "⚠️  Unknown OS, cannot detect resources"
  exit 1
fi

echo "Detected Resources:"
echo "  CPUs: $TOTAL_CPUS"
echo "  Memory: ${TOTAL_MEM_GB}GB"
echo ""

# Calculate available memory (rough estimate)
if [[ "$OSTYPE" == "darwin"* ]]; then
  FREE_MEM_GB=$(echo "scale=1; $(vm_stat | head -1 | grep 'Pages free' | awk '{print $3}' | sed 's/\.//') * 16384 / 1024 / 1024 / 1024" | bc)
else
  FREE_MEM_GB=$(echo "scale=1; $(grep MemAvailable /proc/meminfo 2>/dev/null || grep MemFree /proc/meminfo | awk '{print $2}') / 1024 / 1024" | bc)
fi

echo "  Free Memory: ~${FREE_MEM_GB}GB"
echo ""

# Recommend preset
echo "=== Recommended Preset ==="
if (( $(echo "$TOTAL_MEM_GB < 8" | bc -l) )); then
  echo "⚠️  Warning: Less than 8GB RAM detected."
  echo "   Recommended: barebones (if you need streaming)"
  echo "   Note: This system may not have enough memory for the full stack."
elif (( $(echo "$TOTAL_MEM_GB < 12" | bc -l) )); then
  echo "✓ Recommended: minimal preset"
  echo "  Use 'barebones' if you don't need Superset"
elif (( $(echo "$TOTAL_MEM_GB < 24" | bc -l) )); then
  echo "✓ Recommended: default preset"
  echo "  Use 'minimal' if running other resource-heavy applications"
else
  echo "✓ Recommended: performance preset"
  echo "  You have plenty of resources!"
fi

echo ""
echo "=== Usage ==="
echo "  ./scripts/start.sh <preset>"
echo ""
echo "Available presets: barebones, minimal, default, performance"
```

- [ ] **Step 2: Make script executable**

```bash
chmod +x scripts/check-capacity.sh
```

- [ ] **Step 3: Test the script**

```bash
./scripts/check-capacity.sh
```

Expected: Output showing CPU, Memory, and recommended preset

- [ ] **Step 4: Commit script**

```bash
git add scripts/check-capacity.sh
git commit -m "feat: add system capacity check script"
```

---

### Task 4: Create Start Script

**Files:**
- Create: `scripts/start.sh`

- [ ] **Step 1: Write start script**

```bash
#!/bin/bash
# scripts/start.sh
# Deploy streaming stack to Kubernetes with resource preset

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PRESET=${1:-default}
NAMESPACE=${STREAMING_NAMESPACE:-streaming}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Streaming Stack Deployment ==="
echo "Preset: $PRESET"
echo "Namespace: $NAMESPACE"
echo ""

# Validate preset
if [[ ! "$PRESET" =~ ^(barebones|minimal|default|performance)$ ]]; then
  echo -e "${RED}Error: Invalid preset '$PRESET'${NC}"
  echo "Valid presets: barebones, minimal, default, performance"
  exit 1
fi

# Check kubectl
if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}Error: kubectl not found${NC}"
  echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
  exit 1
fi

# Check helm
if ! command -v helm &> /dev/null; then
  echo -e "${RED}Error: helm not found${NC}"
  echo "Please install helm: https://helm.sh/docs/intro/install/"
  exit 1
fi

# Check cluster connection
echo -e "${YELLOW}Checking cluster connection...${NC}"
if ! kubectl cluster-info &> /dev/null; then
  echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
  echo "Make sure your cluster is running (k3d, minikube, kind, etc.)"
  exit 1
fi
echo -e "${GREEN}✓ Cluster connected${NC}"

# Create namespace if it doesn't exist
echo ""
echo -e "${YELLOW}Creating namespace '$NAMESPACE'...${NC}"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repositories
echo ""
echo -e "${YELLOW}Adding Helm repositories...${NC}"

# Bitnami repository (MySQL, Kafka, MinIO)
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo update > /dev/null 2>&1

# Spark Operator (GoogleCloudPlatform)
helm repo add spark-operator https://googlecloudplatform.github.io/spark-on-k8s-operator 2>/dev/null || true

# Lakekeeper
helm repo add lakekeeper https://lakekeeper.io/charts 2>/dev/null || true

echo -e "${GREEN}✓ Repositories updated${NC}"

# Deploy main chart
echo ""
echo -e "${YELLOW}Deploying streaming-stack...${NC}"
helm upgrade --install streaming-stack "$PROJECT_ROOT/helm/streaming-stack" \
  --namespace "$NAMESPACE" \
  --values "$PROJECT_ROOT/helm/streaming-stack/values-${PRESET}.yaml" \
  --wait --timeout 10m

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Services:"
echo "  Spark UI:      kubectl port-forward -n $NAMESPACE svc/spark-ui 4040:4040"
echo "  MinIO Console: kubectl port-forward -n $NAMESPACE svc/minio 9001:9001"
echo "  Superset:      kubectl port-forward -n $NAMESPACE svc/superset 8088:8088"
echo ""
echo "Run './scripts/verify-stack.sh' to check deployment health"
```

- [ ] **Step 2: Make script executable**

```bash
chmod +x scripts/start.sh
```

- [ ] **Step 3: Commit script**

```bash
git add scripts/start.sh
git commit -m "feat: add deployment start script"
```

---

### Task 5: Create Stop Script

**Files:**
- Create: `scripts/stop.sh`

- [ ] **Step 1: Write stop script**

```bash
#!/bin/bash
# scripts/stop.sh
# Tear down streaming stack from Kubernetes

set -e

NAMESPACE=${STREAMING_NAMESPACE:-streaming}
PURGE_ALL=${PURGE_ALL:-false}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Streaming Stack Teardown ==="
echo "Namespace: $NAMESPACE"
echo ""

# Check if release exists
if ! helm list -n "$NAMESPACE" | grep -q streaming-stack; then
  echo -e "${YELLOW}No streaming-stack release found in namespace $NAMESPACE${NC}"
  exit 0
fi

echo -e "${YELLOW}Uninstalling streaming-stack...${NC}"
helm uninstall streaming-stack -n "$NAMESPACE"

echo -e "${GREEN}✓ Streaming stack uninstalled${NC}"

if [[ "$PURGE_ALL" == "true" ]]; then
  echo ""
  echo -e "${YELLOW}Purging namespace...${NC}"
  kubectl delete namespace "$NAMESPACE"
  echo -e "${GREEN}✓ Namespace deleted${NC}"
else
  echo ""
  echo "Namespace '$NAMESPACE' preserved (includes PVCs with data)"
  echo "Run: kubectl delete namespace $NAMESPACE"
fi
```

- [ ] **Step 2: Make script executable**

```bash
chmod +x scripts/stop.sh
```

- [ ] **Step 3: Commit script**

```bash
git add scripts/stop.sh
git commit -m "feat: add stop script for stack teardown"
```

---

### Task 6: Create Verify Stack Script

**Files:**
- Create: `scripts/verify-stack.sh`

- [ ] **Step 1: Write verify script**

```bash
#!/bin/bash
# scripts/verify-stack.sh
# Verify health of deployed streaming stack

set -e

NAMESPACE=${STREAMING_NAMESPACE:-streaming}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Streaming Stack Health Check ==="
echo ""

check_pods() {
  echo -e "${YELLOW}Checking Pods...${NC}"
  PODS=$(kubectl get pods -n "$NAMESPACE" -o json)

  TOTAL=$(echo "$PODS" | jq '.items | length')
  READY=$(echo "$PODS" | jq '[.items[] | select(.status.phase=="Running")] | length')

  echo "  Pods: $READY/$TOTAL ready"

  # Check for non-running pods
  FAILED=$(echo "$PODS" | jq '[.items[] | select(.status.phase!="Running")] |
    [.[] | {name: .metadata.name, phase: .status.phase}]')

  if [[ "$FAILED" != "[]" ]]; then
    echo -e "${RED}  Non-running pods:${NC}"
    echo "$FAILED" | jq -r '.[] | "    - \(.name): \(.phase)"'
  else
    echo -e "${GREEN}  ✓ All pods running${NC}"
  fi
  echo ""
}

check_kafka() {
  echo -e "${YELLOW}Checking Kafka...${NC}"
  # Try to list topics via kafka-cli
  KAFKA_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=kafka -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$KAFKA_POD" ]]; then
    kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- \
      kafka-topics.sh --bootstrap-server localhost:9092 --list > /dev/null 2>&1 \
      && echo -e "${GREEN}  ✓ Kafka accessible${NC}" \
      || echo -e "${RED}  ✗ Kafka not accessible${NC}"
  else
    echo -e "${YELLOW}  ⚠ Kafka pod not found${NC}"
  fi
  echo ""
}

check_lakekeeper() {
  echo -e "${YELLOW}Checking Lakekeeper...${NC}"
  LAKEKEEPER_SVC=$(kubectl get svc -n "$NAMESPACE" lakekeeper -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)

  if [[ -n "$LAKEKEEPER_SVC" ]]; then
    # Try to access health endpoint
    kubectl run -n "$NAMESPACE" lakekeeper-check --image=curlimages/curl:latest \
      --rm -i --restart=Never -- \
      curl -f -s http://lakekeeper:8181/health > /dev/null 2>&1 \
      && echo -e "${GREEN}  ✓ Lakekeeper healthy${NC}" \
      || echo -e "${RED}  ✗ Lakekeeper not healthy${NC}"
  else
    echo -e "${YELLOW}  ⚠ Lakekeeper service not found${NC}"
  fi
  echo ""
}

check_minio() {
  echo -e "${YELLOW}Checking MinIO...${NC}"
  MINIO_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$MINIO_POD" ]]; then
    kubectl exec -n "$NAMESPACE" "$MINIO_POD" -- \
      mc alias set local http://localhost:9000 minio minio123 > /dev/null 2>&1 \
      && echo -e "${GREEN}  ✓ MinIO accessible${NC}" \
      || echo -e "${RED}  ✗ MinIO not accessible${NC}"
  else
    echo -e "${YELLOW}  ⚠ MinIO pod not found${NC}"
  fi
  echo ""
}

check_spark() {
  echo -e "${YELLOW}Checking Spark...${NC}"
  SPARK_PODS=$(kubectl get pod -n "$NAMESPACE" -l spark-role=driver -o jsonpath='{.items}' 2>/dev/null | jq 'length')

  if [[ "$SPARK_PODS" -gt 0 ]]; then
    echo -e "${GREEN}  ✓ Spark driver running${NC}"
  else
    echo -e "${YELLOW}  ⚠ No Spark driver pods found${NC}"
  fi
  echo ""
}

# Run checks
check_pods
check_kafka
check_lakekeeper
check_minio
check_spark

echo -e "${GREEN}=== Health Check Complete ===${NC}"
```

- [ ] **Step 2: Make script executable**

```bash
chmod +x scripts/verify-stack.sh
```

- [ ] **Step 3: Commit script**

```bash
git add scripts/verify-stack.sh
git commit -m "feat: add stack health verification script"
```

---

### Task 7: Create Integration Test Script

**Files:**
- Create: `scripts/test-integration.sh`

- [ ] **Step 1: Write integration test script**

```bash
#!/bin/bash
# scripts/test-integration.sh
# Run integration tests for streaming stack

set -e

NAMESPACE=${STREAMING_NAMESPACE:-streaming}
FAILURES=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Integration Tests ==="
echo ""

test_kafka_connectivity() {
  echo -e "${YELLOW}Test: Kafka connectivity${NC}"

  KAFKA_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=kafka -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -z "$KAFKA_POD" ]]; then
    echo -e "${RED}  ✗ FAIL: Kafka pod not found${NC}"
    ((FAILURES++))
    return
  fi

  if kubectl exec -n "$NAMESPACE" "$KAFKA_POD" -- \
    kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ PASS${NC}"
  else
    echo -e "${RED}  ✗ FAIL: Cannot connect to Kafka${NC}"
    ((FAILURES++))
  fi
}

test_lakekeeper_catalog() {
  echo -e "${YELLOW}Test: Lakekeeper catalog${NC}"

  LAKEKEEPER_SVC=$(kubectl get svc -n "$NAMESPACE" lakekeeper -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)

  if [[ -z "$LAKEKEEPER_SVC" ]]; then
    echo -e "${RED}  ✗ FAIL: Lakekeeper service not found${NC}"
    ((FAILURES++))
    return
  fi

  HTTP_CODE=$(kubectl run -n "$NAMESPACE" lakekeeper-test --image=curlimages/curl:latest \
    --rm -i --restart=Never -- \
    curl -s -o /dev/null -w "%{http_code}" http://lakekeeper:8181/v1/config 2>/dev/null || echo "000")

  if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "401" ]]; then
    echo -e "${GREEN}  ✓ PASS${NC}"
  else
    echo -e "${RED}  ✗ FAIL: Lakekeeper returned HTTP $HTTP_CODE${NC}"
    ((FAILURES++))
  fi
}

test_minio_buckets() {
  echo -e "${YELLOW}Test: MinIO buckets${NC}"

  MINIO_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -z "$MINIO_POD" ]]; then
    echo -e "${RED}  ✗ FAIL: MinIO pod not found${NC}"
    ((FAILURES++))
    return
  fi

  BUCKETS=$(kubectl exec -n "$NAMESPACE" "$MINIO_POD" -- \
    mc alias set local http://localhost:9000 minio minio123 > /dev/null 2>&1 \
    && mc ls local/ 2>/dev/null | wc -l || echo "0")

  if [[ "$BUCKETS" -gt 0 ]]; then
    echo -e "${GREEN}  ✓ PASS ($BUCKETS buckets found)${NC}"
  else
    echo -e "${RED}  ✗ FAIL: No buckets found${NC}"
    ((FAILURES++))
  fi
}

test_mysql_connection() {
  echo -e "${YELLOW}Test: MySQL connection${NC}"

  MYSQL_POD=$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -z "$MYSQL_POD" ]]; then
    echo -e "${RED}  ✗ FAIL: MySQL pod not found${NC}"
    ((FAILURES++))
    return
  fi

  if kubectl exec -n "$NAMESPACE" "$MYSQL_POD" -- \
    mysqladmin ping -h localhost -u root -prootpw > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ PASS${NC}"
  else
    echo -e "${RED}  ✗ FAIL: Cannot connect to MySQL${NC}"
    ((FAILURES++))
  fi
}

# Run tests
test_kafka_connectivity
test_lakekeeper_catalog
test_minio_buckets
test_mysql_connection

echo ""
echo "=== Test Results ==="
if [[ $FAILURES -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi
```

- [ ] **Step 2: Make script executable**

```bash
chmod +x scripts/test-integration.sh
```

- [ ] **Step 3: Commit script**

```bash
git add scripts/test-integration.sh
git commit -m "feat: add integration test script"
```

---

## Chunk 3: Helm Charts - MySQL

### Task 8: Create MySQL Helm Chart

**Files:**
- Create: `helm/mysql/Chart.yaml`
- Create: `helm/mysql/values.yaml`

- [ ] **Step 1: Create Chart.yaml**

```yaml
apiVersion: v2
name: mysql
description: MySQL database with CDC enabled for streaming
type: application
version: 0.1.0
appVersion: "8.0"
```

- [ ] **Step 2: Create values.yaml with CDC configuration**

```yaml
# helm/mysql/values.yaml

# Use Bitnami MySQL chart
image:
  repository: bitnami/mysql
  tag: 8.0
  pullPolicy: IfNotPresent

auth:
  rootUser: root
  rootPassword: rootpw
  database: appdb

# Primary database configuration
primary:
  configuration: |-
    [mysqld]
    # Enable binary log for CDC
    server-id=1
    log-bin=mysql-bin
    binlog_format=ROW
    binlog_row_image=FULL
    # GTID for safer replication
    gtid_mode=ON
    enforce_gtid_consistency=ON
    # Performance
    max_connections=200
    innodb_buffer_pool_size=128M

  service:
    ports:
      mysql: 3306

  persistence:
    enabled: true
    size: 2Gi
    storageClass: standard

  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

# Init database
initdbScripts:
  init.sql: |
    -- Catalog DB for Iceberg (if using JDBC catalog)
    CREATE DATABASE IF NOT EXISTS iceberg_catalog;

    -- OLTP DB
    CREATE DATABASE IF NOT EXISTS appdb;
    USE appdb;

    CREATE TABLE products (
      id INT PRIMARY KEY AUTO_INCREMENT,
      sku VARCHAR(64) NOT NULL UNIQUE,
      name VARCHAR(128) NOT NULL
    ) ENGINE=InnoDB;

    INSERT INTO products (sku, name) VALUES
    ('P-001','Widget Mini'),
    ('P-002','Widget Standard'),
    ('P-003','Widget Pro'),
    ('P-004','Widget Ultra');

    CREATE TABLE sales (
      id BIGINT PRIMARY KEY AUTO_INCREMENT,
      product_id INT NOT NULL,
      qty INT NOT NULL,
      price DECIMAL(10,2) NOT NULL,
      sale_ts TIMESTAMP NOT NULL,
      CONSTRAINT fk_prod FOREIGN KEY (product_id) REFERENCES products(id)
    ) ENGINE=InnoDB;

    -- Generate sample data
    INSERT INTO sales (product_id, qty, price, sale_ts)
    SELECT
      (ROW_NUMBER() OVER () % 4) + 1 as product_id,
      FLOOR(1 + (RAND() * 4)) as qty,
      CASE ((ROW_NUMBER() OVER () % 4) + 1)
        WHEN 1 THEN 9.99
        WHEN 2 THEN 19.99
        WHEN 3 THEN 29.99
        ELSE 49.99
      END as price,
      DATE_SUB(NOW(), INTERVAL (1095 - ROW_NUMBER() OVER ()) DAY) + INTERVAL (RAND() * 86400) SECOND as sale_ts
    FROM
      (SELECT a.N + b.N * 10 + c.N * 100 + 1 as num
       FROM (SELECT 0 AS N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
             UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
       CROSS JOIN (SELECT 0 AS N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                   UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
       CROSS JOIN (SELECT 0 AS N UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                   UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
      ) numbers
    WHERE num <= 900;
```

- [ ] **Step 3: Commit MySQL chart**

```bash
git add helm/mysql/
git commit -m "feat: add MySQL Helm chart with CDC configuration"
```

---

## Chunk 4: Helm Charts - MinIO

### Task 9: Create MinIO Helm Chart

**Files:**
- Create: `helm/minio/Chart.yaml`
- Create: `helm/minio/values.yaml`
- Create: `helm/minio/create-bucket.sh`

- [ ] **Step 1: Create Chart.yaml**

```yaml
apiVersion: v2
name: minio
description: MinIO S3-compatible storage for Iceberg data
type: application
version: 0.1.0
appVersion: "2025.9.7"
```

- [ ] **Step 2: Create values.yaml**

```yaml
# helm/minio/values.yaml

image:
  repository: quay.io/minio/minio
  tag: RELEASE.2025-09-07T16-13-09Z
  pullPolicy: IfNotPresent

replicas: 1

ports:
  api: 9000
  console: 9001

auth:
  rootUser: minio
  rootPassword: minio123

# Default buckets
defaultBuckets:
  - iceberg
  - warehouse

persistence:
  enabled: true
  size: 5Gi
  storageClass: standard

resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

consoleIngress:
  enabled: false

# Extra script for bucket creation
extraVolumes:
  - name: create-bucket
    configMap:
      name: minio-create-bucket

extraVolumeMounts:
  - name: create-bucket
    mountPath: /scripts

extraInitContainers:
  - name: create-buckets
    image: quay.io/minio/mc:latest
    command: ["/bin/sh", "/scripts/create-bucket.sh"]
    volumeMounts:
      - name: create-bucket
        mountPath: /scripts
```

- [ ] **Step 3: Create bucket creation script**

```bash
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
```

- [ ] **Step 4: Create ConfigMap in values (add to values.yaml)**

Append to `helm/minio/values.yaml`:

```yaml
# ConfigMap for bucket creation script
configMaps:
  create-bucket: |
    #!/bin/sh
    sleep 5
    mc alias set local http://minio:9000 minio minio123
    mc mb local/iceberg --ignore-existing
    mc mb local/warehouse --ignore-existing
    mc ls local/
    echo "MinIO bucket setup completed"
```

- [ ] **Step 5: Commit MinIO chart**

```bash
git add helm/minio/
git commit -m "feat: add MinIO Helm chart with Iceberg buckets"
```

---

## Chunk 5: Helm Charts - Kafka

### Task 10: Create Kafka Helm Chart

**Files:**
- Create: `helm/kafka/Chart.yaml`
- Create: `helm/kafka/values.yaml`
- Create: `helm/kafka/connect/debezium-mysql.json`

- [ ] **Step 1: Create Chart.yaml**

```yaml
apiVersion: v2
name: kafka
description: Kafka with Connect for CDC pipeline
type: application
version: 0.1.0
appVersion: "3.7"
```

- [ ] **Step 2: Create values.yaml**

```yaml
# helm/kafka/values.yaml

# Use Bitnami Kafka chart
kafka:
  enabled: true
  image:
    repository: bitnami/kafka
    tag: 3.7
    # Use a specific tag of Bitnami Kafka that supports KRaft (no Zookeeper needed)
    # Or use traditional Zookeeper setup

  # KRaft mode - no Zookeeper needed
  kraft:
    enabled: true

  replicaCount: 1

  listeners:
    - name: PLAINTEXT
      port: 9092
      protocol: PLAINTEXT

  controller:
    replicaCount: 1

  persistence:
    size: 2Gi
    storageClass: standard

  resources:
    requests:
      cpu: 300m
      memory: 512Mi
    limits:
      cpu: 800m
      memory: 1Gi

  # Topic auto-creation (for CDC topics)
  topicAutoCreation: true

# Kafka Connect
kafkaConnect:
  enabled: true

  image:
    repository: bitnami/kafka
    tag: 3.7

  replicaCount: 1

  resources:
    requests:
      cpu: 200m
      memory: 384Mi
    limits:
      cpu: 500m
      memory: 768Mi

  # Debezium MySQL connector
  externalConfig: |
    {
      "key.converter": "org.apache.kafka.connect.storage.StringConverter",
      "value.converter": "org.apache.kafka.connect.json.JsonConverter",
      "value.converter.schemas.enable": "false",
      "offset.storage.topic": "connect-offsets",
      "offset.storage.replication.factor": "1",
      "config.storage.topic": "connect-configs",
      "config.storage.replication.factor": "1",
      "status.storage.topic": "connect-status",
      "status.storage.replication.factor": "1"
    }

  # Load connectors from ConfigMaps
  loadEnabled: true

# Service configuration
service:
  ports:
    client: 9092
    internal: 9093
```

- [ ] **Step 3: Create Debezium MySQL connector config**

```json
{
  "name": "mysql-cdc-source",
  "config": {
    "connector.class": "io.debezium.connector.mysql.MySqlConnector",
    "database.hostname": "mysql",
    "database.port": "3306",
    "database.user": "root",
    "database.password": "rootpw",
    "database.server.id": "184054",
    "database.server.name": "mysql-cdc",
    "database.include.list": "appdb",
    "table.include.list": "appdb.products,appdb.sales",
    "database.history.kafka.bootstrap.servers": "kafka:9092",
    "database.history.kafka.topic": "schema-changes.appdb",
    "include.schema.changes": "true",
    "snapshot.mode": "initial",
    "binlog.buffer.size": "1024",
    "max.batch.size": "1000",
    "snapshot.fetch.size": "2000"
  }
}
```

- [ ] **Step 4: Commit Kafka chart**

```bash
git add helm/kafka/
git commit -m "feat: add Kafka Helm chart with Debezium connector"
```

---

## Chunk 6: Helm Charts - Lakekeeper

### Task 11: Create Lakekeeper Helm Chart

**Files:**
- Create: `helm/lakekeeper/Chart.yaml`
- Create: `helm/lakekeeper/values.yaml`

- [ ] **Step 1: Create Chart.yaml**

```yaml
apiVersion: v2
name: lakekeeper
description: Iceberg REST Catalog
type: application
version: 0.1.0
appVersion: "0.5.0"
```

- [ ] **Step 2: Create values.yaml**

```yaml
# helm/lakekeeper/values.yaml

# Lakekeeper configuration
replicaCount: 1

image:
  repository: lakekeeper/lakekeeper
  tag: "0.5.0"
  pullPolicy: IfNotPresent

# Service configuration
service:
  type: ClusterIP
  port: 8181

# Storage backend (uses MinIO)
storage:
  type: s3
  s3:
    endpoint: http://minio:9000
    accessKey: minio
    secretKey: minio123
    pathStyleAccess: true
    bucket: iceberg
    prefix: warehouse/

# Catalog configuration
catalog:
  name: lakekeeper
  warehouse: s3://iceberg/warehouse

# Resources
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 300m
    memory: 512Mi

# Environment variables
env:
  - name: LAKEKEEPER_LOG_LEVEL
    value: INFO
  - name: LAKEKEEPER__CATALOG__WAREHOUSE
    value: s3://iceberg/warehouse
  - name: LAKEKEEPER__STORAGE__TYPE
    value: s3
  - name: LAKEKEEPER__STORAGE__S3__ENDPOINT
    value: http://minio:9000
  - name: LAKEKEEPER__STORAGE__S3__ACCESS_KEY
    value: minio
  - name: LAKEKEEPER__STORAGE__S3__SECRET_KEY
    value: minio123
  - name: LAKEKEEPER__STORAGE__S3__PATH_STYLE_ACCESS
    value: "true"

# Health check
livenessProbe:
  httpGet:
    path: /health
    port: 8181
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: 8181
  initialDelaySeconds: 5
  periodSeconds: 5
```

- [ ] **Step 3: Commit Lakekeeper chart**

```bash
git add helm/lakekeeper/
git commit -m "feat: add Lakekeeper Helm chart for Iceberg REST catalog"
```

---

## Chunk 7: Helm Charts - Spark

### Task 12: Create Spark Helm Chart

**Files:**
- Create: `helm/spark/Chart.yaml`
- Create: `helm/spark/values.yaml`
- Create: `helm/spark/jobs/streaming-job.yaml`
- Create: `helm/spark/jobs/thrift-server.yaml`

- [ ] **Step 1: Create Chart.yaml**

```yaml
apiVersion: v2
name: spark
description: Spark Operator and jobs for streaming
type: application
version: 0.1.0
appVersion: "3.5.0"
dependencies:
  - name: spark-operator
    version: 1.1.27
    repository: https://googlecloudplatform.github.io/spark-on-k8s-operator
```

- [ ] **Step 2: Create values.yaml**

```yaml
# helm/spark/values.yaml

# Spark Operator (subchart)
spark-operator:
  enabled: true
  webhook:
    enabled: false
  sparkJobNamespace: streaming

# Common Spark configuration
spark:
  image:
    repository: apache/spark
    tag: "3.5.0"
    pullPolicy: IfNotPresent

  # Event log for Spark UI
  eventLog:
    enabled: true
    dir: /spark/eventLogs

  # Iceberg configuration
  iceberg:
    version: "1.5.0"
    catalog:
      type: rest
      uri: http://lakekeeper:8181
      warehouse: s3://iceberg/warehouse
    s3:
      endpoint: http://minio:9000
      accessKey: minio
      secretKey: minio123
      pathStyleAccess: true

  # Hadoop/S3 configuration
  hadoop:
    aws:
      accessKeyId: minio
      secretAccessKey: minio123
      s3.endpoint: http://minio:9000
      s3.path.style.access: "true"

# Streaming job configuration
streamingJob:
  enabled: true

  name: cdc-streaming-processor

  mainClass: "streaming.CDCContinuousProcessor"
  mainApplicationFile: "local:///opt/spark/jars/streaming-processor.jar"

  # Continuous processing mode
  sparkConf:
    spark.sql.streaming.concurrentQueries: "1"
    spark.sql.streaming.continuous.enabled: "true"
    spark.sql.shuffle.partitions: "2"
    spark.sql.streaming.checkpointLocation: /checkpoints

  driver:
    cores: 1
    coreLimit: "1"
    memory: "1g"
    serviceAccount: spark

  executor:
    cores: 1
    instances: 1
    memory: "1g"

# Thrift server configuration
thriftServer:
  enabled: true

  name: spark-thrift-server

  image:
    repository: apache/spark
    tag: "3.5.0"

  service:
    type: ClusterIP
    port: 10000

  sparkConf:
    spark.hive.server.server2.thrift.port: "10000"
    spark.hive.server.server2.thrift.bind.host: "0.0.0.0"

  driver:
    cores: 1
    coreLimit: "1"
    memory: "1g"

  executor:
    cores: 1
    instances: 1
    memory: "1g"
```

- [ ] **Step 3: Create streaming job CRD**

```yaml
# helm/spark/jobs/streaming-job.yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: cdc-streaming-processor
  namespace: streaming
spec:
  type: Scala
  sparkVersion: "3.5.0"
  mode: cluster
  image: apache/spark:3.5.0
  imagePullPolicy: IfNotPresent
  mainClass: streaming.CDCContinuousProcessor
  mainApplicationFile: local:///opt/spark/jars/streaming-processor.jar
  sparkVersion: "3.5.0"

  # Continuous processing mode
  sparkConf:
    spark.sql.streaming.concurrentQueries: "1"
    spark.sql.streaming.continuous.enabled: "true"
    spark.sql.shuffle.partitions: "2"

    # Iceberg catalog
    spark.sql.catalog.lakekeeper: org.apache.iceberg.spark.SparkCatalog
    spark.sql.catalog.lakekeeper.type: rest
    spark.sql.catalog.lakekeeper.uri: http://lakekeeper:8181
    spark.sql.catalog.lakekeeper.warehouse: s3://iceberg/warehouse
    spark.sql.catalog.lakekeeper.io-impl: org.apache.iceberg.aws.s3.S3FileIO
    spark.sql.catalog.lakekeeper.s3.endpoint: http://minio:9000
    spark.sql.catalog.lakekeeper.s3.access-key-id: minio
    spark.sql.catalog.lakekeeper.s3.secret-access-key: minio123
    spark.sql.catalog.lakekeeper.s3.path-style-access: "true"

    # Kafka consumer config
    spark.kafka.bootstrap.servers: kafka:9092
    spark.kafka.consume.from.beginning: "true"

  driver:
    cores: 1
    coreLimit: "1"
    memory: "1g"
    serviceAccount: spark
  executor:
    cores: 1
    instances: 1
    memory: "1g"

  deps:
    jars:
      - local:///opt/spark/jars/iceberg-spark-runtime-3.5_2.12-1.5.0.jar
      - local:///opt/spark/jars/spark-sql-kafka-0-10_2.12-3.5.0.jar
      - local:///opt/spark/jars/kafka-clients-3.7.0.jar
      - local:///opt/spark/jars/commons-pool2-2.12.0.jar
      - local:///opt/spark/jars/aws-java-sdk-bundle-1.12.666.jar

  monitoring:
    exposeDriverMetrics: true
    exposeExecutorMetrics: true
    prometheus:
      enabled: true
```

- [ ] **Step 4: Create thrift server CRD**

```yaml
# helm/spark/jobs/thrift-server.yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-thrift-server
  namespace: streaming
spec:
  type: Scala
  sparkVersion: "3.5.0"
  mode: cluster
  image: apache/spark:3.5.0
  imagePullPolicy: IfNotPresent
  command: ["/opt/spark/sbin/start-thriftserver.sh"]
  sparkVersion: "3.5.0"

  sparkConf:
    spark.hive.server.server2.thrift.port: "10000"
    spark.hive.server.server2.thrift.bind.host: "0.0.0.0"

    # Iceberg catalog
    spark.sql.catalog.lakekeeper: org.apache.iceberg.spark.SparkCatalog
    spark.sql.catalog.lakekeeper.type: rest
    spark.sql.catalog.lakekeeper.uri: http://lakekeeper:8181
    spark.sql.catalog.lakekeeper.warehouse: s3://iceberg/warehouse
    spark.sql.catalog.lakekeeper.io-impl: org.apache.iceberg.aws.s3.S3FileIO
    spark.sql.catalog.lakekeeper.s3.endpoint: http://minio:9000
    spark.sql.catalog.lakekeeper.s3.access-key-id: minio
    spark.sql.catalog.lakekeeper.s3.secret-access-key: minio123
    spark.sql.catalog.lakekeeper.s3.path-style-access: "true"

  driver:
    cores: 1
    coreLimit: "1"
    memory: "1g"
    serviceAccount: spark
  executor:
    cores: 1
    instances: 1
    memory: "1g"

  deps:
    jars:
      - local:///opt/spark/jars/iceberg-spark-runtime-3.5_2.12-1.5.0.jar
      - local:///opt/spark/jars/aws-java-sdk-bundle-1.12.666.jar

  monitoring:
    exposeDriverMetrics: true
    prometheus:
      enabled: true

  # Service for JDBC access
  restartPolicy: Never
```

- [ ] **Step 5: Commit Spark chart**

```bash
git add helm/spark/
git commit -m "feat: add Spark Helm chart with streaming job and thrift server"
```

---

## Chunk 8: Helm Charts - Superset

### Task 13: Create Superset Helm Chart

**Files:**
- Create: `helm/superset/Chart.yaml`
- Create: `helm/superset/values.yaml`

- [ ] **Step 1: Create Chart.yaml**

```yaml
apiVersion: v2
name: superset
description: Apache Superset BI and visualization
type: application
version: 0.1.0
appVersion: "4.0.0"
```

- [ ] **Step 2: Create values.yaml**

```yaml
# helm/superset/values.yaml

image:
  repository: apache/superset
  tag: 4.0.0
  pullPolicy: IfNotPresent

replicaCount: 1

# Service configuration
service:
  type: ClusterIP
  port: 8088

# Environment variables
env:
  - name: SUPERSET_SECRET_KEY
    value: "streaming-superset-secret-key-change-in-prod"
  - name: ADMIN_USERNAME
    value: "admin"
  - name: ADMIN_FIRST_NAME
    value: "Admin"
  - name: ADMIN_LAST_NAME
    value: "User"
  - name: ADMIN_EMAIL
    value: "admin@example.com"
  - name: ADMIN_PASSWORD
    value: "admin"
  - name: SUPERSET_LOAD_EXAMPLES
    value: "no"
  - name: SUPERSET_PORT
    value: "8088"
  - name: SUPERSET_BIND_ADDRESS
    value: "0.0.0.0"

# Database (use internal SQLite for simplicity)
database:
  type: sqlite

# Cache (internal)
cache:
  type: redis
  host: redis
  port: 6379

# Resources
resources:
  requests:
    cpu: 300m
    memory: 512Mi
  limits:
    cpu: 800m
    memory: 1Gi

# Ingress
ingress:
  enabled: false
```

- [ ] **Step 3: Commit Superset chart**

```bash
git add helm/superset/
git commit -m "feat: add Superset Helm chart"
```

---

## Chunk 9: Umbrella Chart

### Task 14: Create Streaming Stack Umbrella Chart

**Files:**
- Create: `helm/streaming-stack/Chart.yaml`
- Create: `helm/streaming-stack/values.yaml`
- Create: `helm/streaming-stack/values-barebones.yaml`
- Create: `helm/streaming-stack/values-minimal.yaml`
- Create: `helm/streaming-stack/values-default.yaml`
- Create: `helm/streaming-stack/values-performance.yaml`

- [ ] **Step 1: Create Chart.yaml**

```yaml
apiVersion: v2
name: streaming-stack
description: Umbrella chart for streaming processing with Spark
type: application
version: 0.1.0
appVersion: "1.0.0"

dependencies:
  - name: mysql
    version: 0.1.0
    repository: file://../mysql
  - name: minio
    version: 0.1.0
    repository: file://../minio
  - name: kafka
    version: 0.1.0
    repository: file://../kafka
  - name: lakekeeper
    version: 0.1.0
    repository: file://../lakekeeper
  - name: spark
    version: 0.1.0
    repository: file://../spark
  - name: superset
    version: 0.1.0
    repository: file://../superset
    condition: superset.enabled
```

- [ ] **Step 2: Create base values.yaml**

```yaml
# helm/streaming-stack/values.yaml
# Base configuration - minimal preset by default

global:
  namespace: streaming

mysql:
  enabled: true

minio:
  enabled: true

kafka:
  enabled: true

lakekeeper:
  enabled: true

spark:
  enabled: true

superset:
  enabled: false  # Disabled by default, enabled in higher presets
```

- [ ] **Step 3: Create values-barebones.yaml**

```yaml
# helm/streaming-stack/values-barebones.yaml
# Barebones: CDC + Streaming only, ~1.5 cores, 2GB

mysql:
  enabled: true
  auth:
    rootPassword: rootpw

minio:
  enabled: true
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
  kafka:
    replicaCount: 1
    persistence:
      size: 1Gi
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
  kafkaConnect:
    enabled: true
    resources:
      requests:
        cpu: 100m
        memory: 192Mi
      limits:
        cpu: 300m
        memory: 384Mi

lakekeeper:
  enabled: true
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 150m
      memory: 256Mi

spark:
  enabled: true
  streamingJob:
    enabled: true
    driver:
      memory: 512m
      coreLimit: "1"
    executor:
      instances: 1
      memory: 512m
  thriftServer:
    enabled: false

superset:
  enabled: false
```

- [ ] **Step 4: Create values-minimal.yaml**

```yaml
# helm/streaming-stack/values-minimal.yaml
# Minimal: Full stack, ~2.4 cores, 4.5GB

mysql:
  enabled: true

minio:
  enabled: true
  persistence:
    size: 5Gi

kafka:
  enabled: true

lakekeeper:
  enabled: true

spark:
  enabled: true
  streamingJob:
    enabled: true
  thriftServer:
    enabled: true

superset:
  enabled: true
```

- [ ] **Step 5: Create values-default.yaml**

```yaml
# helm/streaming-stack/values-default.yaml
# Default: Comfortable local dev, ~3.5 cores, 6GB

mysql:
  enabled: true

minio:
  enabled: true
  persistence:
    size: 10Gi

kafka:
  enabled: true

lakekeeper:
  enabled: true

spark:
  enabled: true
  streamingJob:
    enabled: true
  thriftServer:
    enabled: true

superset:
  enabled: true
```

- [ ] **Step 6: Create values-performance.yaml**

```yaml
# helm/streaming-stack/values-performance.yaml
# Performance: Production-like testing, ~6+ cores, 10GB+

mysql:
  enabled: true
  primary:
    resources:
      requests:
        cpu: 500m
        memory: 768Mi

minio:
  enabled: true
  persistence:
    size: 20Gi

kafka:
  enabled: true
  kafka:
    replicaCount: 2

lakekeeper:
  enabled: true

spark:
  enabled: true
  streamingJob:
    enabled: true
    driver:
      memory: 2g
    executor:
      instances: 2
      memory: 2g
  thriftServer:
    enabled: true

superset:
  enabled: true
```

- [ ] **Step 7: Commit umbrella chart**

```bash
git add helm/streaming-stack/
git commit -m "feat: add streaming stack umbrella chart with resource presets"
```

---

## Chunk 10: Spark Streaming Job Code

### Task 15: Create Spark Streaming Processor

**Files:**
- Create: `spark-jobs/streaming-processor/build.sbt`
- Create: `spark-jobs/streaming-processor/src/main/scala/streaming/CDCContinuousProcessor.scala`

- [ ] **Step 1: Create build.sbt**

```scala
name := "streaming-processor"

version := "0.1.0"

scalaVersion := "2.12.18"

val sparkVersion = "3.5.0"
val icebergVersion = "1.5.0"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-sql" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-sql-kafka-0-10" % sparkVersion,
  "org.apache.iceberg" %% "iceberg-spark-runtime-3.5_2.12" % icebergVersion,
  "org.apache.iceberg" %% "iceberg-kafka" % icebergVersion,
  "org.apache.hadoop" % "hadoop-aws" % "3.3.4",
  "com.amazonaws" % "aws-java-sdk-bundle" % "1.12.666"
)

assembly / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case x => MergeStrategy.first
}
```

- [ ] **Step 2: Create the streaming processor**

```scala
package streaming

import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.functions._
import org.apache.spark.sql.types._
import org.apache.spark.sql.streaming.Trigger

/**
 * Continuous streaming processor that reads CDC from Kafka,
 * joins products and sales, and writes to Iceberg.
 *
 * Run with:
 * spark-submit \
 *   --master k8s://https://kubernetes.default.svc \
 *   --deploy-mode cluster \
 *   --class streaming.CDCContinuousProcessor \
 *   --conf spark.kubernetes.container.image=apache/spark:3.5.0 \
 *   local:///opt/spark/jars/streaming-processor.jar
 */
object CDCContinuousProcessor {

  def main(args: Array[String]): Unit = {

    val spark = SparkSession.builder()
      .appName("CDC Continuous Streaming Processor")
      .config("spark.sql.streaming.schemaInference", "true")
      .config("spark.sql.streaming.forceDeleteTempCheckpointLocation", "true")
      .getOrCreate()

    import spark.implicits._

    // Kafka configuration
    val kafkaBootstrapServers = sys.env.getOrElse("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")

    // Schema for Debezium CDC events
    val cdcSchema = StructType(Seq(
      StructField("before", StringType, nullable = true),
      StructField("after", StringType, nullable = true),
      StructField("source", StructType(Seq(
        StructField("table", StringType),
        StructField("ts_ms", LongType)
      ))),
      StructField("op", StringType),
      StructField("ts_ms", LongType)
    ))

    // Read products CDC from Kafka
    val productsRaw = spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", kafkaBootstrapServers)
      .option("subscribe", "mysql-cdc.appdb.products")
      .option("startingOffsets", "earliest")
      .load()

    val products = productsRaw
      .select(from_json($"value".cast("string"), cdcSchema).as("data"))
      .select(
        $"data.after".cast("string"),
        $"data.op",
        $"data.source.table"
      )
      .filter($"table" === "products")
      .select(
        from_json($"after", StructType(Seq(
          StructField("id", IntegerType),
          StructField("sku", StringType),
          StructField("name", StringType)
        ))).as("product")
      )
      .select("product.*")
      .as[Product]

    // Read sales CDC from Kafka
    val salesRaw = spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", kafkaBootstrapServers)
      .option("subscribe", "mysql-cdc.appdb.sales")
      .option("startingOffsets", "earliest")
      .load()

    val sales = salesRaw
      .select(from_json($"value".cast("string"), cdcSchema).as("data"))
      .select(
        $"data.after".cast("string"),
        $"data.op",
        $"data.source.table"
      )
      .filter($"table" === "sales")
      .select(
        from_json($"after", StructType(Seq(
          StructField("id", LongType),
          StructField("product_id", IntegerType),
          StructField("qty", IntegerType),
          StructField("price", DecimalType(10, 2)),
          StructField("sale_ts", TimestampType)
        ))).as("sale")
      )
      .select("sale.*")
      .as[Sale]

    // Watermark for late-arriving data
    val salesWithWatermark = sales
      .withWatermark("sale_ts", "1 minute")

    // Join with products and aggregate
    val salesByProduct = salesWithWatermark
      .join(products, $"product_id" === $"id", "inner")
      .groupBy(
        $"product_id",
        $"sku".as("product_sku"),
        $"name".as("product_name")
      )
      .agg(
        sum($"qty").as("total_qty"),
        sum($"qty" * $"price").as("total_revenue"),
        count("*").as("sale_count"),
        max($"sale_ts").as("last_sale_ts")
      )

    // Write to Iceberg in continuous mode
    val query = salesByProduct.writeStream
      .format("iceberg")
      .outputMode("update")
      .trigger(Trigger.Continuous("1 second"))
      .option("checkpointLocation", "/checkpoints/sales-by-product")
      .option("path", "lakekeeper.demo.sales_by_product")
      .foreachBatch { (batchDF: org.apache.spark.sql.DataFrame, batchId: Long) =>
        // Write micro-batch to Iceberg
        batchDF.write
          .format("iceberg")
          .mode("append")
          .save("lakekeeper.demo.sales_by_product")
      }
      .start()

    query.awaitTermination()
  }
}

// Case classes for data
case class Product(id: Int, sku: String, name: String)
case class Sale(id: Long, product_id: Int, qty: Int, price: java.math.BigDecimal, sale_ts: java.sql.Timestamp)
```

- [ ] **Step 3: Create build and push script**

```bash
#!/bin/bash
# spark-jobs/scripts/build-and-push.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

IMAGE_NAME=${IMAGE_NAME:-"streaming-processor"}
IMAGE_TAG=${IMAGE_TAG:-"latest"}

echo "=== Building Streaming Processor ==="
echo "Image: $IMAGE_NAME:$IMAGE_TAG"
echo ""

cd "$PROJECT_ROOT/streaming-processor"

# Build with sbt
sbt clean assembly

echo ""
echo "=== Building Docker Image ==="
docker build -t "$IMAGE_NAME:$IMAGE_TAG" .
echo "✓ Build complete: $IMAGE_NAME:$IMAGE_TAG"

if [[ -n "$PUSH_TO_REGISTRY" ]]; then
  echo ""
  echo "=== Pushing to Registry ==="
  docker push "$IMAGE_NAME:$IMAGE_TAG"
fi
```

- [ ] **Step 4: Create Dockerfile for the job**

```dockerfile
# spark-jobs/streaming-processor/Dockerfile
FROM apache/spark:3.5.0

# Copy the assembled jar
COPY target/scala-2.12/streaming-processor-assembly-*.jar /opt/spark/jars/streaming-processor.jar

# Copy additional dependencies
COPY jars /opt/spark/jars/

WORKDIR /opt/spark
```

- [ ] **Step 5: Commit Spark job code**

```bash
git add spark-jobs/
git commit -m "feat: add Spark continuous streaming processor"
```

---

## Chunk 11: Tests

### Task 16: Create E2E Test

**Files:**
- Create: `tests/e2e/cdc-to-iceberg-test.yaml`
- Create: `tests/e2e/run-e2e.sh`

- [ ] **Step 1: Create E2E test manifest**

```yaml
# tests/e2e/cdc-to-iceberg-test.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: e2e-test-script
  namespace: streaming
data:
  test.sh: |
    #!/bin/bash
    set -e

    echo "=== E2E Test: MySQL → Kafka → Spark → Iceberg ==="
    echo ""

    # 1. Insert test data into MySQL
    echo "Step 1: Inserting test data into MySQL..."
    TEST_SKU="E2E-TEST-$(date +%s)"
    mysql -h mysql -u root -prootpw appdb <<EOF
    INSERT INTO products (sku, name) VALUES ('$TEST_SKU', 'E2E Test Product');
    INSERT INTO sales (product_id, qty, price, sale_ts)
    VALUES ((SELECT id FROM products WHERE sku = '$TEST_SKU'), 10, 99.99, NOW());
    EOF
    echo "✓ Test data inserted"
    echo ""

    # 2. Wait for data to flow through Kafka and Spark
    echo "Step 2: Waiting for streaming to process (max 60 seconds)..."
    for i in {1..60}; do
      # Check via Spark SQL
      RESULT=$(spark-sql \
        -e "SELECT COUNT(*) FROM lakekeeper.demo.sales_by_product WHERE product_sku = '$TEST_SKU';" \
        2>/dev/null | tail -1 || echo "0")

      if [[ "$RESULT" -gt 0 ]]; then
        echo "✓ Data appeared in Iceberg after ${i}s"
        echo "  SKU: $TEST_SKU"
        echo "  Records found: $RESULT"
        exit 0
      fi
      sleep 1
    done

    echo "✗ E2E test failed: data did not appear in Iceberg within 60 seconds"
    exit 1
```

- [ ] **Step 2: Create E2E test runner script**

```bash
#!/bin/bash
# tests/e2e/run-e2e.sh

set -e

NAMESPACE=${STREAMING_NAMESPACE:-streaming}

echo "=== Running E2E Tests ==="
echo ""

# Apply test ConfigMap
kubectl apply -f tests/e2e/cdc-to-iceberg-test.yaml

# Run the test
echo "Launching test pod..."
kubectl run e2e-test \
  --namespace "$NAMESPACE" \
  --image=mysql:8.0 \
  --restart=Never \
  --command -- bash /scripts/test.sh \
  --overrides='
  {
    "spec": {
      "containers": [{
        "name": "e2e-test",
        "env": [
          {"name": "MYSQL_HOST", "value": "mysql"}
        ],
        "volumeMounts": [{
          "name": "test-script",
          "mountPath": "/scripts"
        }]
      }],
      "volumes": [{
        "name": "test-script",
        "configMap": {
          "name": "e2e-test-script"
        }
      }],
      "restartPolicy": "Never"
    }
  }'

# Wait for completion
echo "Waiting for test completion..."
kubectl wait --for=condition=complete --timeout=120s pod/e2e-test -n "$NAMESPACE"

# Get logs
echo ""
echo "=== Test Output ==="
kubectl logs e2e-test -n "$NAMESPACE"

# Check exit code
EXIT_CODE=$(kubectl get pod e2e-test -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}')

# Cleanup
kubectl delete pod e2e-test -n "$NAMESPACE"
kubectl delete configmap e2e-test-script -n "$NAMESPACE"

if [[ "$EXIT_CODE" == "0" ]]; then
  echo ""
  echo "✓ E2E tests passed"
  exit 0
else
  echo ""
  echo "✗ E2E tests failed with exit code $EXIT_CODE"
  exit 1
fi
```

- [ ] **Step 3: Make test scripts executable**

```bash
chmod +x tests/e2e/run-e2e.sh
```

- [ ] **Step 4: Commit E2E tests**

```bash
git add tests/e2e/
git commit -m "feat: add E2E test for CDC to Iceberg pipeline"
```

---

### Task 17: Create Integration Test

**Files:**
- Create: `tests/integration/connectivity-test.sh`

- [ ] **Step 1: Create connectivity test**

```bash
#!/bin/bash
# tests/integration/connectivity-test.sh
# Test connectivity between all components

set -e

NAMESPACE=${STREAMING_NAMESPACE:-streaming}

echo "=== Integration Connectivity Tests ==="
echo ""

FAILURES=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_result() {
  local test_name=$1
  local result=$2
  if [[ $result -eq 0 ]]; then
    echo -e "${GREEN}✓ PASS${NC}: $test_name"
  else
    echo -e "${RED}✗ FAIL${NC}: $test_name"
    ((FAILURES++))
  fi
}

# Test MySQL → Kafka (Debezium)
echo -e "${YELLOW}Testing: MySQL → Kafka (Debezium)${NC}"
kubectl exec -n "$NAMESPACE" deploy/kafka -- \
  kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic mysql-cdc.appdb.products \
    --from-beginning \
    --timeout-ms 5000 \
    --max-messages 1 >/dev/null 2>&1
test_result "MySQL → Kafka CDC" $?

# Test Kafka → Spark (consumer)
echo -e "${YELLOW}Testing: Kafka → Spark Consumer${NC}"
# Check if Spark driver can connect to Kafka
SPARK_POD=$(kubectl get pod -n "$NAMESPACE" -l spark-role=driver -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$SPARK_POD" ]]; then
  kubectl exec -n "$NAMESPACE" "$SPARK_POD" -- \
    nc -zv kafka 9092 >/dev/null 2>&1
  test_result "Spark → Kafka connectivity" $?
else
  echo -e "${YELLOW}⚠ SKIP${NC}: No Spark driver pod found"
fi

# Test Spark → Lakekeeper
echo -e "${YELLOW}Testing: Spark → Lakekeeper${NC}"
kubectl run -n "$NAMESPACE" connectivity-test --image=curlimages/curl:latest \
  --rm -i --restart=Never -- \
  curl -f -s http://lakekeeper:8181/v1/config >/dev/null 2>&1
test_result "Lakekeeper REST API" $?

# Test Lakekeeper → MinIO
echo -e "${YELLOW}Testing: Lakekeeper → MinIO${NC}"
kubectl exec -n "$NAMESPACE" deploy/lakekeeper -- \
  curl -f -s http://minio:9000/minio/health/live >/dev/null 2>&1
test_result "MinIO health" $?

echo ""
echo "=== Results ==="
if [[ $FAILURES -eq 0 ]]; then
  echo -e "${GREEN}All connectivity tests passed!${NC}"
  exit 0
else
  echo -e "${RED}$FAILURES test(s) failed${NC}"
  exit 1
fi
```

- [ ] **Step 2: Make script executable**

```bash
chmod +x tests/integration/connectivity-test.sh
```

- [ ] **Step 3: Commit integration tests**

```bash
git add tests/integration/
git commit -m "feat: add integration connectivity tests"
```

---

## Chunk 12: Documentation

### Task 18: Create Documentation

**Files:**
- Create: `docs/architecture.md`
- Create: `docs/deployment-guide.md`
- Create: `docs/troubleshooting.md`
- Update: `README.md`

- [ ] **Step 1: Create architecture documentation**

```markdown
# Architecture Overview

## Overview

The streaming stack provides real-time data processing from MySQL CDC to analytics-ready Iceberg tables using Apache Spark in continuous processing mode.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Kubernetes Cluster                             │
│                                                                             │
│  MySQL → Kafka Connect → Kafka → Spark Streaming (Continuous) → Iceberg    │
│                                                           (Lakekeeper)     │
│                                                                   ↓         │
│                                                           Spark SQL         │
│                                                                   ↓         │
│                                                              Superset       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| **MySQL** | Source database with CDC | MySQL 8.0 |
| **Kafka** | Event streaming platform | Apache Kafka 3.7 |
| **Debezium** | CDC connector | Debezium 2.x |
| **Spark** | Stream processing and analytics | Apache Spark 3.5 |
| **Lakekeeper** | Iceberg REST catalog | Lakekeeper 0.5 |
| **MinIO** | S3-compatible storage | MinIO |
| **Superset** | BI and visualization | Apache Superset |

## Data Flow

### 1. CDC Capture
- MySQL writes changes to binlog
- Debezium (via Kafka Connect) captures binlog
- Events written to Kafka topics

### 2. Stream Processing
- Spark Structured Streaming reads from Kafka
- Continuous processing mode: ~1ms latency
- Joins and aggregations performed in-memory
- Results written to Iceberg

### 3. Query
- Superset connects via JDBC to Spark Thrift Server
- Spark SQL queries Iceberg tables
- MinIO serves data files

## Resource Presets

| Preset | CPUs | Memory | Use Case |
|--------|------|--------|----------|
| barebones | 1.5 | 2GB | CDC + Streaming only |
| minimal | 2.4 | 4.5GB | Full stack, single executor |
| default | 3.5 | 6GB | Comfortable local dev |
| performance | 6+ | 10GB | Production-like |
```

- [ ] **Step 2: Create deployment guide**

```markdown
# Deployment Guide

## Prerequisites

- Kubernetes cluster (k3d, minikube, kind, or GKE/AKS/EKS)
- kubectl configured
- helm 3.x installed
- At least 8GB RAM (16GB recommended)

## Quick Start

1. **Check system capacity:**
   ```bash
   ./scripts/check-capacity.sh
   ```

2. **Deploy the stack:**
   ```bash
   ./scripts/start.sh minimal
   ```

3. **Verify deployment:**
   ```bash
   ./scripts/verify-stack.sh
   ```

4. **Run integration tests:**
   ```bash
   ./scripts/test-integration.sh
   ```

## Accessing Services

| Service | Command |
|---------|---------|
| Spark UI | `kubectl port-forward -n streaming svc/spark-ui 4040:4040` |
| MinIO Console | `kubectl port-forward -n streaming svc/minio 9001:9001` |
| Superset | `kubectl port-forward -n streaming svc/superset 8088:8088` |

## Stopping the Stack

```bash
./scripts/stop.sh
```

To purge everything including PVCs:
```bash
PURGE_ALL=true ./scripts/stop.sh
```

## Resource Presets

Choose a preset based on your system:

- `barebones`: Streaming only, no Superset
- `minimal`: Full stack, minimal resources
- `default`: Balanced for local development
- `performance`: Production-like resources
```

- [ ] **Step 3: Create troubleshooting guide**

```markdown
# Troubleshooting

## Common Issues

### Spark driver crashes

**Symptom:** Spark driver pod is in CrashLoopBackOff

**Solutions:**
1. Check logs: `kubectl logs -n streaming cdc-streaming-process-driver`
2. Verify Kafka connectivity: `kubectl exec -it -n streaming kafka -- kafka-broker-api-versions --bootstrap-server localhost:9092`
3. Check Lakekeeper: `kubectl logs -n streaming deploy/lakekeeper`

### No data in Iceberg tables

**Symptom:** Queries return empty results

**Solutions:**
1. Check Kafka topics have data:
   ```bash
   kubectl exec -it -n streaming kafka -- \
     kafka-console-consumer --bootstrap-server localhost:9092 \
     --topic mysql-cdc.appdb.sales --from-beginning --max-messages 10
   ```

2. Check Spark streaming progress:
   ```bash
   kubectl exec -it -n streaming cdc-streaming-process-driver -- \
     spark-submit --status
   ```

3. Verify Lakekeeper catalog:
   ```bash
   curl http://lakekeeper:8181/v1/namespaces
   ```

### Out of memory errors

**Symptom:** Pods being OOMKilled

**Solutions:**
1. Use a smaller preset: `./scripts/start.sh barebones`
2. Check resource usage: `kubectl top pods -n streaming`
3. Increase memory limits in values file

### Debezium not capturing changes

**Symptom:** No new events in Kafka topics

**Solutions:**
1. Check MySQL binlog is enabled:
   ```sql
   SHOW VARIABLES LIKE 'binlog%';
   ```

2. Verify Kafka Connect connector status:
   ```bash
   kubectl exec -it -n streaming kafka-connect-0 -- \
     curl localhost:8083/connectors/mysql-cdc-source/status
   ```

## Getting Help

- Check logs: `kubectl logs -n streaming <pod-name>`
- Describe pod: `kubectl describe pod -n streaming <pod-name>`
- Events: `kubectl get events -n streaming --sort-by='.lastTimestamp'`
```

- [ ] **Step 4: Update README**

```markdown
# Streaming Processing v1

Real-time streaming processing using Apache Spark with continuous processing mode.

## Quick Start

```bash
# Check your system capacity
./scripts/check-capacity.sh

# Deploy with recommended preset
./scripts/start.sh minimal

# Verify deployment
./scripts/verify-stack.sh
```

## Architecture

```
MySQL CDC → Kafka → Spark Streaming → Iceberg → Spark SQL → Superset
         (Continuous Mode)         (Lakekeeper)
```

## Documentation

- [Architecture Overview](docs/architecture.md)
- [Deployment Guide](docs/deployment-guide.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Implementation Plan](docs/superpowers/plans/2026-03-14-spark-continuous-streaming-plan.md)

## Resource Presets

| Preset | CPUs | Memory | Description |
|--------|------|--------|-------------|
| barebones | 1.5 | 2GB | Streaming only |
| minimal | 2.4 | 4.5GB | Full stack |
| default | 3.5 | 6GB | Local dev |
| performance | 6+ | 10GB+ | Production-like |

## Development

See [deployment guide](docs/deployment-guide.md) for detailed instructions.
```

- [ ] **Step 5: Commit documentation**

```bash
git add docs/ README.md
git commit -m "docs: add architecture, deployment, and troubleshooting guides"
```

---

## Chunk 13: Final Setup and Migration

### Task 19: Clean up old v1 files

**Files:**
- Delete: `docker-compose.yml`
- Delete: `Dockerfile`
- Delete: `Dockerfile.cron`
- Delete: `submit-flink-job.sh`
- Delete: `insert-sales-data-loop.sh`
- Delete: `verify-stack.sh` (old version)
- Delete: `jobs/` directory
- Delete: `trino/` directory

- [ ] **Step 1: Archive old files (don't delete yet)**

```bash
mkdir -p .archive/v1-original
mv docker-compose.yml .archive/v1-original/
mv Dockerfile* .archive/v1-original/
mv submit-flink-job.sh .archive/v1-original/
mv insert-sales-data-loop.sh .archive/v1-original/
mv verify-stack.sh .archive/v1-original/
mv jobs/ .archive/v1-original/
mv trino/ .archive/v1-original/
```

- [ ] **Step 2: Archive data directory if it exists**

```bash
if [ -d "data" ]; then
  mv data/ .archive/v1-original/
fi
```

- [ ] **Step 3: Commit archive**

```bash
git add .archive/
git commit -m "chore: archive original v1 files before migration"
```

### Task 20: Create Helm Dependencies File

**Files:**
- Create: `helm/streaming-stack/Chart.lock`

- [ ] **Step 1: Initialize Helm dependencies**

```bash
cd helm/streaming-stack
helm dependency update
cd ../..
```

- [ ] **Step 2: Commit Chart.lock**

```bash
git add helm/streaming-stack/Chart.lock
git commit -m "chore: add Helm dependency lock file"
```

---

## Implementation Complete Checklist

After completing all tasks:

- [ ] All scripts are executable (`chmod +x scripts/*.sh`)
- [ ] All Helm charts validate (`helm lint helm/*/`)
- [ ] Documentation is complete
- [ ] Old files are archived
- [ ] Git history is clean with descriptive commits

---

## Next Steps After Implementation

1. **Build the Spark job:**
   ```bash
   cd spark-jobs/streaming-processor
   sbt assembly
   docker build -t streaming-processor:latest .
   ```

2. **Deploy to local cluster:**
   ```bash
   ./scripts/start.sh minimal
   ```

3. **Run tests:**
   ```bash
   ./scripts/verify-stack.sh
   ./scripts/test-integration.sh
   ./tests/e2e/run-e2e.sh
   ```

---

**Plan Status:** Ready for execution

**Total Tasks:** 20
**Estimated Time:** 4-6 hours for full implementation
