#!/bin/bash

# colors for logging
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color


show_help() {
  echo -e "${GREEN}Usage:${NC}"
  echo "  $0 dev [-s|--skip] [-v|--verbose] [-d|--delete]"
  echo "  $0 migrate [-v|--verbose]"
  echo "  $0 -h|--help"
  echo ""
  echo -e "${YELLOW}Commands:${NC}"
  echo "  dev         Starts the stack in development mode"
  echo "  migrate     Creates Flask migrations"
  echo ""
  echo -e "${YELLOW}Options:${NC}"
  echo "  -s, --skip      Skip the database upgrade in dev mode"
  echo "  -v, --verbose   Run in verbose mode (stream all input/output to terminal)"
  echo "  -d, --delete    Delete the volume 'annotation_data' before starting"
  echo "  -h, --help      Show this help message"
  echo ""
  echo ""
  echo -e "${YELLOW}Tip:${NC}"
  echo "It might be useful to alias 'run.sh'"
  exit 0
}

run_command() {
  if [ "$VERBOSE" = true ]; then
    set -x # Enable command tracing
    $@
    set +x # Disable command tracing
  else
    # Allow Docker Compose commands to show their output for `up`
    if [[ $1 == "docker" && $2 == "compose" && $3 == "up" && $4 != "-d" ]]; then
      $@ -d # Add `--detach` to prevent showing container logs
    else
      $@ > /dev/null 2>&1 # Suppress output for other commands
    fi
  fi
}

cleanup() {
  echo -e "\n${YELLOW}Stopping all running containers...${NC}"
  docker compose down
  echo -e "\033[0;32m Cleanup complete. Exiting. \033[0m"
  exit 0
}

# Attach the cleanup function to SIGINT (CTRL+C)
trap cleanup SIGINT 

COMMAND=""
SKIP=false
VERBOSE=false
DELETE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    dev)
      COMMAND="dev"
      shift
      ;;
    migrate)
      COMMAND="migrate"
      shift
      ;;
    -s|--skip)
      SKIP=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -d|--delete)
      DELETE=true
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      show_help
      ;;
  esac
done

if [[ -z "$COMMAND" ]]; then
  echo -e "${RED}Error: No command provided.${NC}"
  show_help
fi


case $COMMAND in
  dev)
    if [ "$DELETE" = true ]; then
      echo -e "${YELLOW}Deleting (volume/database) 'annotation_data'...${NC}"
      run_command docker volume rm annotation_data
      echo -e "${GREEN}(Volume/Database) deleted successfully.${NC}"
    fi
    if [ "$SKIP" = false ]; then
      echo -e "${GREEN}Starting database container...${NC}"
      run_command docker compose up -d db
      
      echo -e "${GREEN}Run Flask database upgrade...${NC}"
      run_command docker compose run --rm flask flask db upgrade
      
      echo -e "${GREEN}Stopping database container...${NC}"
      run_command docker compose down
    fi
    
    echo -e "${GREEN}Starting the dev stack...${NC}"
    run_command docker compose up
  
    echo ""
    echo -e "${GREEN}Dev stack started (Press CTRL+C to stop)...${NC}"
    echo ""
    # Infinite loop to wait for CTRL+C
    while true; do
      sleep 1
    done
    ;;
  
  migrate)
    echo -e "${GREEN}Starting database container...${NC}"
    run_command docker compose up -d db
    
    echo -e "${GREEN}Create Flask database migration...${NC}"
    run_command docker compose run --rm flask flask db migrate
    
    echo -e "${GREEN}Stopping database container...${NC}"
    run_command docker compose down
    ;;
  
  *)
    echo -e "${RED}Unknown command: $COMMAND${NC}"
    show_help
    ;;
esac
