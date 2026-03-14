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

# Validate chart directory exists
if [[ ! -d "$PROJECT_ROOT/helm/streaming-stack" ]]; then
  echo -e "${RED}Error: Chart directory not found: $PROJECT_ROOT/helm/streaming-stack${NC}"
  echo "Please complete the Helm chart setup first (see implementation plan)"
  exit 1
fi

# Validate values file exists
VALUES_FILE="$PROJECT_ROOT/helm/streaming-stack/values-${PRESET}.yaml"
if [[ ! -f "$VALUES_FILE" ]]; then
  echo -e "${RED}Error: Values file not found: $VALUES_FILE${NC}"
  echo "Available presets: barebones, minimal, default, performance"
  exit 1
fi

# Deploy main chart
echo ""
echo -e "${YELLOW}Deploying streaming-stack...${NC}"
helm upgrade --install streaming-stack "$PROJECT_ROOT/helm/streaming-stack" \
  --namespace "$NAMESPACE" \
  --values "$VALUES_FILE" \
  --wait --timeout 10m

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Services:"
echo "  Spark UI:      kubectl port-forward -n $NAMESPACE svc/spark-ui 4040:4040"
echo "  MinIO Console: kubectl port-forward -n $NAMESPACE svc/minio 9001:9001"
echo "  Superset:      kubectl port-forward -n $NAMESPACE svc/superset 8088:8088"
echo ""
echo "Check deployment status:"
echo "  kubectl get pods -n $NAMESPACE"
echo ""
echo "Note: Full verification script (scripts/verify-stack.sh) will be available after completing all implementation tasks."
