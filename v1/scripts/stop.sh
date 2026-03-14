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
  echo "Or: PURGE_ALL=true ./scripts/stop.sh"
fi
