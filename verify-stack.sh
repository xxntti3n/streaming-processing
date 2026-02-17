#!/bin/bash
# Verify end-to-end streaming: MySQL CDC → Flink (join + aggregate) → Iceberg → Trino

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "OK" ]; then
        echo -e "${GREEN}✓${NC} $message"
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}✗${NC} $message"
    elif [ "$status" = "INFO" ]; then
        echo -e "${BLUE}ℹ${NC} $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
    fi
}

check_container() {
    local container=$1
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        print_status "OK" "Container $container is running"
        return 0
    else
        print_status "FAIL" "Container $container is NOT running"
        return 1
    fi
}

wait_for_service() {
    local service_name=$1
    local service_url=$2
    local max_attempts=30
    local attempt=1
    print_status "INFO" "Waiting for $service_name..."
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$service_url" > /dev/null 2>&1; then
            print_status "OK" "$service_name is ready"
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
    done
    print_status "FAIL" "$service_name did not become ready"
    return 1
}

# Trino: accept 200/302 (root or UI), more attempts (startup can be slow)
wait_for_trino() {
    local max_attempts=45
    local attempt=1
    print_status "INFO" "Waiting for Trino..."
    while [ $attempt -le $max_attempts ]; do
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" -L "http://localhost:8080" 2>/dev/null || true)
        if [ "$code" = "200" ] || [ "$code" = "302" ]; then
            print_status "OK" "Trino is ready"
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
    done
    print_status "FAIL" "Trino did not become ready"
    return 1
}

main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Streaming Stack Verification${NC}"
    echo -e "${BLUE}  MySQL CDC → Flink → Iceberg → Trino${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    echo -e "${BLUE}Step 1: Containers${NC}"
    echo "-------------------------------------------"
    all_ok=true
    check_container "streaming-mysql" || all_ok=false
    check_container "streaming-minio" || all_ok=false
    check_container "streaming-jobmanager" || all_ok=false
    docker ps --format '{{.Names}}' | grep -qE "streaming-processing-taskmanager|streaming-processing_taskmanager" && print_status "OK" "Container taskmanager(s) running" || print_status "FAIL" "Container taskmanager(s) NOT running"
    check_container "streaming-trino" || all_ok=false
    check_container "streaming-superset" || true
    echo ""

    if [ "$all_ok" = false ]; then
        print_status "FAIL" "Start stack: docker compose up -d"
        exit 1
    fi

    echo -e "${BLUE}Step 2: Service health${NC}"
    echo "-------------------------------------------"
    wait_for_service "Flink" "http://localhost:8081"
    wait_for_trino
    wait_for_service "MinIO" "http://localhost:9000/minio/health/live"
    echo ""

    echo -e "${BLUE}Step 3: MySQL CDC${NC}"
    echo "-------------------------------------------"
    binlog=$(docker exec streaming-mysql mysql -u root -prootpw -e "SHOW VARIABLES LIKE 'binlog_format';" -t -N 2>/dev/null | awk '{print $2}')
    if [ "$binlog" = "ROW" ]; then
        print_status "OK" "MySQL binlog_format=ROW"
    else
        print_status "FAIL" "MySQL binlog_format is not ROW"
    fi
    rowimg=$(docker exec streaming-mysql mysql -u root -prootpw -e "SHOW VARIABLES LIKE 'binlog_row_image';" -t -N 2>/dev/null | awk '{print $2}')
    if [ "$rowimg" = "FULL" ]; then
        print_status "OK" "MySQL binlog_row_image=FULL"
    else
        print_status "FAIL" "MySQL binlog_row_image is not FULL"
    fi
    echo ""

    echo -e "${BLUE}Step 4: Iceberg catalog DB${NC}"
    echo "-------------------------------------------"
    if docker exec streaming-mysql mysql -u root -prootpw -e "SHOW DATABASES LIKE 'iceberg_catalog';" -t -N 2>/dev/null | grep -q iceberg_catalog; then
        print_status "OK" "iceberg_catalog database exists"
    else
        print_status "WARN" "iceberg_catalog not found (created by sql/init.sql on first run)"
    fi
    echo ""

    echo -e "${BLUE}Step 5: MinIO bucket${NC}"
    echo "-------------------------------------------"
    if docker exec streaming-mc mc ls local 2>/dev/null | grep -q iceberg; then
        print_status "OK" "MinIO bucket 'iceberg' exists"
    else
        print_status "WARN" "MinIO bucket 'iceberg' not found (mc creates it on first run)"
    fi
    echo ""

    echo -e "${BLUE}Step 6: Flink job${NC}"
    echo "-------------------------------------------"
    running=$(docker exec streaming-jobmanager /opt/flink/bin/flink list -r 2>/dev/null | grep -c "RUNNING" || true)
    if [ "${running:-0}" -gt 0 ]; then
        print_status "OK" "Flink streaming job(s) running"
    else
        print_status "INFO" "No Flink job running. Submit: ./submit-flink-job.sh"
    fi
    echo ""

    echo -e "${BLUE}Step 7: Trino ↔ Iceberg${NC}"
    echo "-------------------------------------------"
    cats=$(docker exec streaming-trino trino --execute "SHOW CATALOGS" -t 2>/dev/null | tr -d ' ' | grep -c iceberg || true)
    if [ "${cats:-0}" -gt 0 ]; then
        print_status "OK" "Trino sees Iceberg catalog"
    else
        print_status "FAIL" "Trino does not see Iceberg catalog"
    fi
    if docker exec streaming-trino trino --execute "SHOW DATABASES FROM iceberg" -t 2>/dev/null | grep -q demo; then
        print_status "OK" "Iceberg database 'demo' exists"
    else
        print_status "WARN" "Iceberg 'demo' not found (created when Flink job runs)"
    fi
    echo ""

    echo -e "${BLUE}Step 8: Result table sales_by_product${NC}"
    echo "-------------------------------------------"
    if docker exec streaming-trino trino --execute "SHOW TABLES FROM iceberg.demo" -t 2>/dev/null | grep -q sales_by_product; then
        print_status "OK" "Table iceberg.demo.sales_by_product exists"
        count=$(docker exec streaming-trino trino --execute "SELECT COUNT(*) FROM iceberg.demo.sales_by_product" -t 2>/dev/null | tr -d ' ' || echo "0")
        print_status "OK" "Row count: $count"
    else
        print_status "WARN" "Table sales_by_product not found (submit Flink job first)"
    fi
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Verification complete${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${GREEN}URLs:${NC}"
    echo -e "  Flink:    http://localhost:8081"
    echo -e "  Trino:    http://localhost:8080"
    echo -e "  MinIO:    http://localhost:9001 (minio/minio123)"
    echo -e "  Superset: http://localhost:8088 (admin/admin)"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  Submit job:  ./submit-flink-job.sh"
    echo -e "  Trino:       docker exec streaming-trino trino --execute \"SELECT * FROM iceberg.demo.sales_by_product\""
    echo -e "  Insert row:  docker exec streaming-mysql mysql -u root -prootpw -e \"INSERT INTO appdb.sales (product_id, qty, price, sale_ts) VALUES (1, 2, 9.99, NOW());\""
    echo ""
}

main
