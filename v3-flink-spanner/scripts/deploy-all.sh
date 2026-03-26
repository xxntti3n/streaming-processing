#!/bin/bash
# deploy-all.sh - Deploy all infrastructure services
set -e

NAMESPACE="${NAMESPACE:-default}"

echo "=================================================="
echo "Deploying CDC Infrastructure"
echo "=================================================="
echo "Namespace: $NAMESPACE"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Create namespace if it doesn't exist
echo "Creating namespace..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Deploying services..."
echo ""

# Deploy Spanner emulator
echo "1. Deploying Spanner emulator..."
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: spanner-emulator
  namespace: default
spec:
  selector:
    app: spanner-emulator
  ports:
  - port: 9010
    targetPort: 9010
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spanner-emulator
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: spanner-emulator
  template:
    metadata:
      labels:
        app: spanner-emulator
    spec:
      containers:
      - name: spanner-emulator
        image: gcr.io/cloud-spanner-emulator/emulator:1.4.0
        ports:
        - containerPort: 9010
        env:
        - name: SPANNER_EMULATOR_HOST
          value: "0.0.0.0:9010"
EOF

# Deploy MinIO
echo "2. Deploying MinIO..."
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: default
spec:
  selector:
    app: minio
  ports:
  - name: api
    port: 9000
    targetPort: 9301
  - name: console
    port: 9400
    targetPort: 9400
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: default
spec:
  replicas: 1
  selector:
    app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: quay.io/minio/minio:latest
        command:
        - server
        - "--address"
        - "0.0.0.0:9301"
        - "--console-address"
        - "0.0.0.0:9400"
        - /data
        env:
        - name: MINIO_ROOT_USER
          value: "minioadmin"
        - name: MINIO_ROOT_PASSWORD
          value: "minioadmin"
        ports:
        - containerPort: 9301
        - containerPort: 9400
        volumeMounts:
        - name: minio-data
          mountPath: /data
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      volumes:
      - name: minio-data
        emptyDir: {}
EOF

# Create MinIO buckets
echo "2.1. Creating MinIO buckets..."
kubectl run --rm minio-init --image=minio/mc --restart=Never --command='
  /bin/sh -c "
  until /usr/bin/mc alias set minio http://minio:9000 minioadmin minioadmin; do echo waiting...; sleep 1; done
  /usr/bin/mc mb minio/hummock001 --ignore-existing
  /usr/bin/mc mb minio/warehouse --ignore-existing
  echo MinIO buckets initialized
  "

# Deploy Lakekeeper (replacing old iceberg-rest-catalog)
echo "2.2. Deploying Lakekeeper..."
kubectl apply -f deployments/02-lakekeeper-db.yaml
kubectl apply -f deployments/02-lakekeeper-migrate.yaml
kubectl apply -f deployments/02-lakekeeper.yaml
kubectl apply -f deployments/02-lakekeeper-bootstrap.yaml

# Deploy Flink cluster
echo "3. Deploying Flink cluster..."
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: flink-jobmanager
  namespace: default
spec:
  selector:
    app: flink
    component: jobmanager
  ports:
  - name: rpc
    port: 6123
    targetPort: 6123
  - name: blob
    port: 6124
    targetPort: 6124
  - name: ui
    port: 8081
    targetPort: 8081
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flink-jobmanager
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: flink
      component: jobmanager
  template:
    metadata:
      labels:
        app: flink
        component: jobmanager
    spec:
      containers:
      - name: jobmanager
        image: flink:1.19.1
        args:
        - jobmanager
        ports:
        - containerPort: 6123
        - containerPort: 6124
        - containerPort: 8081
        env:
        - name: FLINK_PROPERTIES
          value: |
            jobmanager.rpc.address: flink-jobmanager
            taskmanager.numberOfTaskSlots: 2
---
apiVersion: v1
kind: Service
metadata:
  name: flink-taskmanager
  namespace: default
spec:
  selector:
    app: flink
    component: taskmanager
  ports:
  - name: rpc
    port: 6122
    targetPort: 6122
  - name: data
    port: 6121
    targetPort: 6121
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flink-taskmanager
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: flink
      component: taskmanager
  template:
    metadata:
      labels:
        app: flink
        component: taskmanager
    spec:
      containers:
      - name: taskmanager
        image: flink:1.19.1
        args:
        - taskmanager
        ports:
        - containerPort: 6121
        - containerPort: 6122
        env:
        - name: FLINK_PROPERTIES
          value: |
            jobmanager.rpc.address: flink-jobmanager
            taskmanager.numberOfTaskSlots: 2
EOF

echo ""
echo "=================================================="
echo "Deployment Complete!"
echo "=================================================="
echo ""
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=spanner-emulator -n "$NAMESPACE" --timeout=60s 2>/dev/null || echo "Spanner emulator pending..."
kubectl wait --for=condition=ready pod -l app=flink,component=jobmanager -n "$NAMESPACE" --timeout=60s 2>/dev/null || echo "Flink JobManager pending..."

echo ""
echo "Services deployed:"
echo "  Spanner emulator: spanner-emulator:9010"
echo "  BigQuery emulator: bigquery-emulator:9050"
echo "  Flink Web UI: kubectl port-forward svc/flink-jobmanager 8081:8081"
echo ""
echo "Next steps:"
echo "  1. ./scripts/build-cdc-job.sh"
echo "  2. ./scripts/submit-cdc-job.sh"
echo "  3. ./scripts/verify-cdc-pipeline.sh"
