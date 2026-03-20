#!/usr/bin/env python3
"""
Simple Spanner setup script that works with the emulator.
Run with: kubectl port-forward svc/spanner-emulator 9010:9010 & python3 setup-spanner.py
"""

import os
import sys

# IMPORTANT: Set emulator host BEFORE importing google.cloud.spanner
os.environ['SPANNER_EMULATOR_HOST'] = os.environ.get('SPANNER_EMULATOR_HOST', 'localhost:9010')

import time
import subprocess

# Install dependencies if needed
try:
    import grpc
except ImportError:
    print("Installing grpcio...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "grpcio", "-q"])
    import grpc

try:
    from google.cloud import spanner
    from google.cloud.spanner_v1 import instance as instance_module
    from google.cloud.spanner_v1 import database as database_module
except ImportError:
    print("Installing google-cloud-spanner...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "google-cloud-spanner", "-q"])
    from google.cloud import spanner

def test_connection():
    """Test connection to Spanner emulator."""
    import socket
    host = os.environ.get('SPANNER_EMULATOR_HOST', 'localhost:9010').split(':')[0]
    port = int(os.environ.get('SPANNER_EMULATOR_HOST', 'localhost:9010').split(':')[1])

    for i in range(30):
        try:
            sock = socket.create_connection((host, port), timeout=2)
            sock.close()
            print(f"✓ Connected to Spanner emulator at {host}:{port}")
            return True
        except:
            time.sleep(1)
    print(f"✗ Failed to connect to Spanner emulator at {host}:{port}")
    return False

def main():
    print("=" * 50)
    print("Spanner Emulator Setup")
    print("=" * 50)
    print()

    # Test connection
    if not test_connection():
        print("\nMake sure kubectl port-forward is running:")
    print("  kubectl port-forward svc/spanner-emulator 9010:9010")
        sys.exit(1)

    print("\nNote: The Spanner emulator requires the following to be pre-created:")
    print("  1. Instance: test-instance")
    print("  2. Database: ecommerce")
    print("  3. Tables: customers, products, orders")
    print("  4. Change Stream: ecommerce_change_stream")
    print()
    print("Due to Python library limitations with the emulator,")
    print("please use one of these methods to create the database:")
    print()
    print("Method 1 - Using Docker with kind network:")
    print("  docker run --rm --network kind \\")
    print("    -e SPANNER_EMULATOR_HOST=spanner-emulator:9010 \\")
    print("    gcr.io/google.com/cloudsdktool/cloud-sdk:slim \\")
    print("    gcloud spanner instances create test-instance \\")
    print("      --config=emulator-config --project=test-project")
    print()
    print("Method 2 - Using gcloud CLI locally (requires gcloud):")
    print("  export SPANNER_EMULATOR_HOST=localhost:9010")
    print("  gcloud spanner instances create test-instance \\")
    print("    --config=emulator-config --project=test-project")
    print()
    print("After creating the instance and database, the Flink job should run.")

if __name__ == "__main__":
    main()
