#!/bin/bash
# Direct Docker approach to setup Spanner by running inside kind network
set -e

echo "Setting up Spanner directly via Docker..."

# Get the Spanner emulator container ID
SPANNER_CONTAINER=$(docker exec spanner-cdc-flink-worker crictl ps --quiet | grep -m1 spanner)
echo "Spanner container: $SPANNER_CONTAINER"

# Get the Spanner emulator IP
SPANNER_IP=$(docker exec spanner-cdc-flink-worker crictl inspect "$SPANNER_CONTAINER" 2>/dev/null | grep -o '"ip":[^}]*"10\.[0-9.]*' | grep -o '10\.[0-9.]*' | head -1)
echo "Spanner IP: $SPANNER_IP"

# Check if port is accessible from the kind node
docker exec spanner-cdc-flink-worker nc -z "$SPANNER_IP" 9010 && echo "Port 9010 is accessible" || echo "Port 9010 not accessible"

# Now run a Python container that connects to the kind network
docker run --rm --network kind python:3.11-slim bash -c "
pip install grpcio protobuf -q 2>/dev/null

python3 << 'PYEOF'
import grpc
import time

# We'll compile minimal protobuf definitions inline
# For now, let's try to connect to see if the emulator is reachable

try:
    channel = grpc.insecure_channel('10.244.1.5:9010')
    # Try a simple health check
    from grpc.health.v1 import health_pb2, health_pb2_grpc
    stub = health_pb2_grpc.HealthStub(channel)
    response = stub.Check(health_pb2.HealthCheckRequest(service=''))
    print(f'Health check: {response.status}')
except Exception as e:
    print(f'Health check failed: {e}')

print('Done!')
PYEOF
" 2>&1 || echo "Failed to run setup"

echo "Setup attempt complete!"
