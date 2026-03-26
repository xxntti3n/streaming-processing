#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  dbt-risingwave for CDC Pipeline${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DBT_DIR="$PROJECT_DIR/dbt"

# Set dbt profiles directory
export DBT_PROFILES_DIR="$DBT_DIR"

case "${1:-help}" in
  init)
    echo -e "${YELLOW}Initializing dbt project...${NC}"
    cd "$DBT_DIR"
    dbt init --profiles-dir "$DBT_DIR" || echo "Project already initialized"
    ;;

  debug)
    echo -e "${YELLOW}Testing dbt connection to RisingWave...${NC}"
    cd "$DBT_DIR"
    dbt debug --profiles-dir "$DBT_DIR"
    ;;

  deps)
    echo -e "${YELLOW}Installing dbt dependencies...${NC}"
    cd "$DBT_DIR"
    dbt deps --profiles-dir "$DBT_DIR"
    ;;

  run)
    echo -e "${YELLOW}Running dbt models...${NC}"
    cd "$DBT_DIR"
    dbt run --profiles-dir "$DBT_DIR" "${@:2}"
    ;;

  run-full)
    echo -e "${YELLOW}Running dbt with full refresh...${NC}"
    cd "$DBT_DIR"
    dbt run --full-refresh --profiles-dir "$DBT_DIR" "${@:2}"
    ;;

  test)
    echo -e "${YELLOW}Running dbt tests...${NC}"
    cd "$DBT_DIR"
    dbt test --profiles-dir "$DBT_DIR" "${@:2}"
    ;;

  build)
    echo -e "${YELLOW}Building dbt project (run + test)...${NC}"
    cd "$DBT_DIR"
    dbt build --profiles-dir "$DBT_DIR" "${@:2}"
    ;;

  compile)
    echo -e "${YELLOW}Compiling dbt models...${NC}"
    cd "$DBT_DIR"
    dbt compile --profiles-dir "$DBT_DIR"
    ;;

  generate)
    echo -e "${YELLOW}Generating dbt documentation...${NC}"
    cd "$DBT_DIR"
    dbt docs generate --profiles-dir "$DBT_DIR"
    ;;

  docs)
    echo -e "${YELLOW}Serving dbt documentation...${NC}"
    cd "$DBT_DIR"
    dbt docs serve --profiles-dir "$DBT_DIR"
    ;;

  clean)
    echo -e "${YELLOW}Cleaning dbt target directory...${NC}"
    cd "$DBT_DIR"
    dbt clean --profiles-dir "$DBT_DIR"
    ;;

  list)
    echo -e "${YELLOW}Listing dbt models...${NC}"
    cd "$DBT_DIR"
    dbt list --profiles-dir "$DBT_DIR" "${@:2}"
    ;;

  show)
    echo -e "${YELLOW}Showing model SQL...${NC}"
    cd "$DBT_DIR"
    dbt show --profiles-dir "$DBT_DIR" "${@:2}"
    ;;

  *)
    echo -e "${GREEN}dbt-risingwave CLI${NC}"
    echo ""
    echo "Usage: ./scripts/dbt.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init          Initialize dbt project"
    echo "  debug         Test connection to RisingWave"
    echo "  deps          Install dependencies"
    echo "  run [model]   Run models (e.g., 'run stg_customers')"
    echo "  run-full      Run with full refresh"
    echo "  test          Run data tests"
    echo "  build         Run models + tests"
    echo "  compile       Compile models (show generated SQL)"
    echo "  generate      Generate documentation"
    echo "  docs          Serve documentation site"
    echo "  clean         Clean target directory"
    echo "  list          List all models"
    echo "  show <model>  Show model details"
    echo ""
    echo "Examples:"
    echo "  ./scripts/dbt.sh debug"
    echo "  ./scripts/dbt.sh run"
    echo "  ./scripts/dbt.sh run +fct_customer_order_summary"
    echo "  ./scripts/dbt.sh test"
    echo "  ./scripts/dbt.sh list"
    echo ""
    ;;
esac
