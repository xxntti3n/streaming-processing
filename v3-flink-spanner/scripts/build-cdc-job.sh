#!/bin/bash
# build-cdc-job.sh - Build the Flink CDC job JAR
set -e

cd "$(dirname "$0")/../flink-jobs/spanner-cdc"

echo "=================================================="
echo "Building Flink CDC Job JAR"
echo "=================================================="

# Check if Maven is installed
if ! command -v mvn &> /dev/null; then
    echo "Error: Maven (mvn) is not installed"
    echo "Install Maven: https://maven.apache.org/install.html"
    exit 1
fi

# Run Maven build
echo "Running Maven package..."
mvn clean package -DskipTests

# Check if JAR was created
JAR_FILE=target/spanner-cdc-bigquery-1.0-SNAPSHOT.jar
if [ -f "$JAR_FILE" ]; then
    echo ""
    echo "Build successful!"
    echo "JAR: $JAR_FILE"
    ls -lh "$JAR_FILE"
else
    echo ""
    echo "Build failed - JAR not found"
    exit 1
fi
