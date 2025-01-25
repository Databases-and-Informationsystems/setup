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
  echo "  $0 restore create <name>"
  echo "  $0 restore"
  echo "  $0 test [api|difference-calc]"
  echo "  $0 -h|--help"
  echo ""
  echo -e "${YELLOW}Commands:${NC}"
  echo "  dev         Starts the stack in development mode"
  echo "  migrate     Creates Flask migrations"
  echo "  restore     Manages annotation_data volumes"
  echo "  test        Runs tests (all, api, or difference-calc)"
  echo ""
  echo -e "${YELLOW}Options:${NC}"
  echo "  -s, --skip      Skip the database upgrade in dev mode"
  echo "  -v, --verbose   Run in verbose mode (stream all input/output to terminal)"
  echo "  -d, --delete    Delete the volume annotation_data before starting"
  echo "  -h, --help      Show this help message"
  echo ""
  echo ""
  echo -e "${YELLOW}Tip:${NC}"
  echo "It might be useful to alias ./run.sh"
}

run_command() {
  if [ "$VERBOSE" = true ] || [[ "$@" == *"flask db upgrade"* ]]; then
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

TRACKED_FILES=("../../api/requirements.txt" "../../api/Dockerfile" "../../pipeline/requirements.txt" "../../pipeline/Dockerfile" "../../difference-calc/requirements.txt" "../../difference-calc/Dockerfile" "../../frontend/Dockerfile" "../../frontend/package.json")
CHECKSUM_FILE=".build_checksum"

check_files_changes() {
  for file in "${TRACKED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
      echo -e "${RED}Error: $file not found.${NC}"
      exit 1
    fi
  done

  CURRENT_CHECKSUM=$(cat "${TRACKED_FILES[@]}" | sha256sum | awk '{ print $1 }')

  if [ ! -f "$CHECKSUM_FILE" ]; then
    echo "$CURRENT_CHECKSUM" > "$CHECKSUM_FILE"
    echo -e "${YELLOW}No previous checksum found. Building images...${NC}"
    return 0
  fi

  SAVED_CHECKSUM=$(cat "$CHECKSUM_FILE")
  if [ "$CURRENT_CHECKSUM" != "$SAVED_CHECKSUM" ]; then
    echo "$CURRENT_CHECKSUM" > "$CHECKSUM_FILE"
    echo -e "${YELLOW}Tracked files changed. Rebuilding images...${NC}"
    return 0
  else
    echo -e "${GREEN}Tracked files unchanged. Skipping build...${NC}"
    return 1
  fi
}

clone_volume() {
  local source_volume=$1
  local target_volume=$2

  echo -e "${YELLOW}Cloning volume '${source_volume}' to '${target_volume}'...${NC}"

  docker volume create "$target_volume" > /dev/null 2>&1

  docker run --rm \
    -v "${source_volume}:/from" \
    -v "${target_volume}:/to" \
    alpine ash -c "cd /from && cp -a . /to" > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Volume '${target_volume}' created successfully!${NC}"
  else
    echo -e "${RED}Failed to clone volume '${source_volume}' to '${target_volume}'.${NC}"
    exit 1
  fi
}

restore_create() {
  local volume_name=$1
  if [ -z "$volume_name" ]; then
    echo -e "${RED}Error: No volume name provided.${NC}"
    echo -e "${YELLOW}Usage: $0 restore create <name>${NC}"
    exit 1
  fi

  clone_volume "annotation_data" "annotation_data_$volume_name"
}

restore_select() {
  echo -e "${YELLOW}Available volumes:${NC}"

  local volumes=( $(docker volume ls --filter name=annotation_data_ --format "{{.Name}}") )
  if [ ${#volumes[@]} -eq 0 ]; then
    echo -e "${RED}No cloned volumes found.${NC}"
    exit 1
  fi

  for i in "${!volumes[@]}"; do
    # Strip the prefix "annotation_data_" from each volume name
    local stripped_name=${volumes[$i]#annotation_data_}
    echo "$((i + 1)). ${stripped_name}"
  done

  echo -ne "\n${GREEN}Enter the number of the volume to use:${NC} "
  read selection

  if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#volumes[@]} ]; then
    echo -e "${RED}Invalid selection. No volume was selected.${NC}"
    exit 1
  fi

  local selected_volume=${volumes[$((selection - 1))]}

  echo -e "${YELLOW}Replacing 'annotation_data' with '${selected_volume}'...${NC}"

  docker volume rm annotation_data > /dev/null 2>&1
  docker volume create --name annotation_data > /dev/null 2>&1

  docker run --rm \
    -v "${selected_volume}:/from" \
    -v "annotation_data:/to" \
    alpine ash -c "cd /from && cp -a . /to" > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Volume 'annotation_data' replaced successfully with '${selected_volume}'!${NC}"
  else
    echo -e "${RED}Failed to replace 'annotation_data' with '${selected_volume}'.${NC}"
    exit 1
  fi
}


cleanup() {
  echo -e "\n${YELLOW}Stopping all running containers...${NC}"
  docker compose down

  echo -e "\033[0;32m Cleanup complete. Exiting. \033[0m"
  exit 0
}

test() {
  local target=$1

  if [ "$target" == "api" ] || [ -z "$target" ]; then
    echo -e "${GREEN}Running Unittests in Backend (API) project...${NC}"
    docker compose run --rm annotation_backend python -m unittest discover -s tests
    BACKEND_TEST_EXIT_CODE=$?

    if [ $BACKEND_TEST_EXIT_CODE -eq 0 ]; then
      echo -e "${GREEN}All unittests in Backend (API) passed!${NC}"
    else
      echo -e "${RED}Some unittests in Backend (API) failed!${NC}"
    fi
  fi

  if [ "$target" == "difference-calc" ] || [ -z "$target" ]; then
    echo -e "${GREEN}Running Pytest in Difference-Calc project...${NC}"
    docker compose run --rm annotation_difference_calc pytest
    DIFF_CALC_TEST_EXIT_CODE=$?

    if [ $DIFF_CALC_TEST_EXIT_CODE -eq 0 ]; then
      echo -e "${GREEN}All Pytest tests in Difference-Calc passed!${NC}"
    else
      echo -e "${RED}Some Pytest tests in Difference-Calc failed!${NC}"
    fi
  fi

  if [ "$target" == "api" ]; then
    exit $BACKEND_TEST_EXIT_CODE
  elif [ "$target" == "difference-calc" ]; then
    exit $DIFF_CALC_TEST_EXIT_CODE
  else
    if [ $BACKEND_TEST_EXIT_CODE -eq 0 ] && [ $DIFF_CALC_TEST_EXIT_CODE -eq 0 ]; then
      echo -e "${GREEN}All tests passed successfully!${NC}"
      exit 0
    else
      echo -e "${RED}Some tests failed. Please check the logs above.${NC}"
      exit 1
    fi
  fi
}

# Attach the cleanup function to SIGINT (CTRL+C)
trap cleanup SIGINT 

COMMAND=""
SUBCOMMAND=""
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
    test)
      COMMAND="test"
      shift
      SUBCOMMAND=$1
      shift
      ;;
    restore)
      COMMAND="restore"
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
      exit 0
      ;;
    create)
      SUBCOMMAND="create"
      shift
      ;;
    *)
      if [ -z "$SUBCOMMAND" ]; then
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        exit 0
      else
        ARGS+=("$1")
        shift
      fi
      ;;
  esac
done

if [[ -z "$COMMAND" ]]; then
  echo -e "${RED}Error: No command provided.${NC}"
  show_help
fi

case $COMMAND in
  dev)
    if check_files_changes; then
      run_command docker compose build
    fi

    if [ "$DELETE" = true ]; then
      echo -e "${YELLOW}Deleting (volume/database) 'annotation_data'...${NC}"
      run_command docker volume rm annotation_data > /dev/null 2>&1
      echo -e "${GREEN}(Volume/Database) deleted successfully.${NC}"
    fi

    echo -e "${YELLOW}Checking for the existence of the 'annotation_data' volume...${NC}"

    if ! docker volume inspect annotation_data > /dev/null 2>&1; then
      echo -e "${RED}Volume 'annotation_data' not found.${NC}"
      echo -e "${YELLOW}Creating a new 'annotation_data' volume...${NC}"
      docker volume create annotation_data > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}Volume 'annotation_data' created successfully!${NC}"
      else
        echo -e "${RED}Failed to create volume 'annotation_data'. Exiting...${NC}"
        exit 1
      fi
    else
      echo -e "${GREEN}Volume 'annotation_data' already exists.${NC}"
    fi


    if [ "$SKIP" = false ]; then
      echo -e "${GREEN}Starting database container...${NC}"
      run_command docker compose up -d annotation_database  > /dev/null
      
      echo -e "${GREEN}Run Flask database upgrade...${NC}"
      run_command docker compose run --rm annotation_backend flask db upgrade > /dev/null
      
      echo -e "${GREEN}Stopping database container...${NC}"
      run_command docker compose down annotation_database > /dev/null
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
    run_command docker compose up -d annotation_database > /dev/null
    
    echo -e "${GREEN}Create Flask database migration...${NC}"
    run_command docker compose run --rm annotation_backend flask db migrate
    if [ $? -ne 0 ]; then
      echo -e "${RED}Flask database upgrade failed! Exiting...${NC}"
      # run_command docker compose down db -v
      run_command docker compose down annotation_database
      exit 1
    fi
    echo -e "${GREEN}Stopping database container...${NC}"
    run_command docker compose down > /dev/null
    ;;

  test)
    test "$SUBCOMMAND"
    ;;

  restore)
   case $SUBCOMMAND in
      create)
        restore_create "${ARGS[0]}"
        ;;
      "")
        restore_select
        ;;
      *)
        echo -e "${RED}Unknown subcommand for restore: $SUBCOMMAND${NC}"
        show_help
        exit 1
        ;;
    esac
    ;;
  
  *)
    echo -e "${RED}Unknown command: $COMMAND${NC}"
    show_help
    ;;
esac
