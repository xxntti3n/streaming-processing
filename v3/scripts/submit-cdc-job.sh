#!/bin/bash
# submit-cdc-job.sh - Submit the Flink CDC job to the cluster
set -e

NAMESPACE="${NAMESPACE:-default}"
JOB_NAME="spanner-cdc-bigquery"
JAR_FILE="flink-jobs/spanner-cdc/target/spanner-cdc-bigquery-1.0-SNAPSHOT.jar"
MAIN_CLASS="com.example.streaming.SpannerCdcPipeline"
PARALLELISM="${PARALLELISM:-1}"

echo "=================================================="
echo "Submitting Flink CDC Job"
echo "=================================================="
echo "Namespace: $NAMESPACE"
echo "Job Name: $JOB_NAME"
echo "Parallelism: $PARALLELISM"
echo ""

# Ensure kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Ensure JAR exists
if [ ! -f "$JAR_FILE" ]; then
    echo "Error: JAR file not found: $JAR_FILE"
    echo "Run ./scripts/build-cdc-job.sh first"
    exit 1
fi

# Get JobManager pod
JM_POD=$(kubectl get pod -l app=flink,component=jobmanager -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
JM_DEPLOYMENT=$(kubectl get deployment flink-jobmanager -n "$NAMESPACE" -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")

if [ -z "$JM_POD" ] && [ -z "$JM_DEPLOYMENT" ]; then
    echo "Error: Flink JobManager not found in namespace '$NAMESPACE'"
    echo "Please deploy Flink first"
    exit 1
fi

# Use deployment if pod not found
if [ -z "$JM_POD" ]; then
    echo "Using JobManager deployment: $JM_DEPLOYMENT"
    kubectl exec deployment/"$JM_DEPLOYMENT" -n "$NAMESPACE" -- /opt/flink/bin/flink run \
        -c $MAIN_CLASS \
        -d \
        --classname $MAIN_CLASS \
        -p $PARALLELISM \
        /tmp/spanner-cdc-bigquery-1.0-SNAPSHOT.jar
else
    echo "Copying JAR to JobManager pod: $JM_POD"
    kubectl cp "$JAR_FILE" "$NAMESPACE/$JM_POD:/tmp/"

    # Submit job via Flink CLI
    echo "Submitting job to Flink..."
    kubectl exec "$JM_POD" -n "$NAMESPACE" -- /opt/flink/bin/flink run \
        -c $MAIN_CLASS \
        -d \
        --classname $MAIN_CLASS \
        -p $PARALLELISM \
        /tmp/spanner-cdc-bigquery-1.0-SNAPSHOT.jar
fi

echo ""
echo "Job submitted!"
echo ""
echo "View job status:"
echo "  kubectl port-forward -n $NAMESPACE svc/flink-jobmanager 8081:8081"
echo "  Open: http://localhost:8081"
