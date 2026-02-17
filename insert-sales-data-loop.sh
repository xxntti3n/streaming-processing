#!/bin/bash

###############################################################################
# MySQL Data Inserter for CDC Pipeline Testing
# Inserts test sales records into MySQL every 10 seconds
###############################################################################

# Use environment variables with defaults
MYSQL_HOST=${MYSQL_HOST:-mysql}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_USER=${MYSQL_USER:-root}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-rootpw}
DATABASE=${DATABASE:-appdb}
INTERVAL=${INTERVAL:-10}  # Default 10 seconds

# Counter for batches
BATCH=1

echo "=============================================="
echo "MySQL Data Inserter Started"
echo "Target: ${MYSQL_HOST}:${MYSQL_PORT}/${DATABASE}"
echo "Interval: ${INTERVAL} seconds"
echo "=============================================="
echo ""

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
until mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SELECT 1" >/dev/null 2>&1; do
    echo "MySQL is unavailable - sleeping"
    sleep 2
done

echo "MySQL is ready! Starting data insertion..."
echo ""

# Infinite loop to insert data every INTERVAL seconds
while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # Get count of existing records
    COUNT=$(mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "
        USE ${DATABASE};
        SELECT COUNT(*) FROM sales;
    " 2>&1 | grep -v "Warning" | tail -1)

    echo "[$TIMESTAMP] [Batch #$BATCH] Inserting new sales records..."

    # Insert 10 random sales records
    mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "
        USE ${DATABASE};
        INSERT INTO sales (product_id, qty, price, sale_ts)
        SELECT
          (FLOOR(RAND() * 4) + 1) as product_id,
          FLOOR(1 + (RAND() * 4)) as qty,
          CASE (FLOOR(RAND() * 4) + 1)
            WHEN 1 THEN 9.99
            WHEN 2 THEN 19.99
            WHEN 3 THEN 29.99
            ELSE 49.99
          END as price,
          NOW() as sale_ts
        FROM (
          SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
          UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
          UNION ALL SELECT 9 UNION ALL SELECT 10
        ) numbers;
    " 2>&1 | grep -v "Warning"

    # Verify the insert
    NEW_COUNT=$(mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "
        USE ${DATABASE};
        SELECT COUNT(*) FROM sales;
    " 2>&1 | grep -v "Warning" | tail -1)

    INSERTED=$((NEW_COUNT - COUNT))
    echo "✓ Inserted ${INSERTED} records. Total records: ${NEW_COUNT}"
    echo ""

    BATCH=$((BATCH + 1))

    # Wait for INTERVAL seconds
    sleep ${INTERVAL}
done
