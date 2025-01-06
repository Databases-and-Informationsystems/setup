#!/bin/bash

### ---------------------------------------------------------------
# pre commit hook to verify the python code is formatted using black and there is no direct commit to the main branch
### ---------------------------------------------------------------
# Use .githooks folder instead of .git/hooks to use the hooks in this Project
#
#    git config core.hooksPath ./.githooks
#
# Make sure the file is executable
#
#    chmod 744 ./.githooks/pre-commit
#
### ---------------------------------------------------------------

DOCKER_COMPOSE_FILE=$1
REPO_NAME=$2
CURRENT_BRANCH=$3
CHANGED_PYTHON_FILES=$4

REPO_PATH="/app/$REPO_NAME"

# Prevent commits directly to main or master
#CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" || "$CURRENT_BRANCH" == "development" ]]; then
  echo "Direct commits to the '$CURRENT_BRANCH' branch are not allowed."
  echo "Please create a feature branch and commit your changes there."
  exit 1
fi

if [ -z "$CHANGED_PYTHON_FILES" ]; then
  echo "No Python files to check."
  exit 0
fi

echo "Checking the following files with Black:"
echo "$CHANGED_PYTHON_FILES"

# Check if the Black container is running to return a better error message
# shellcheck disable=SC2016
if ! docker ps --format '{{.Names}}' | grep -q 'python-black-container'; then
  echo "Error: The 'python-black-container' is not running."
  echo "Please start the container using the following command:"
  echo "You need the setup repository for this: https://github.com/Databases-and-Informationsystems/setup"
  echo ""
  echo "cd ../setup/dev/docker/pre-commit"
  echo "docker compose up -d"
  echo ""
fi

# Run Black in the Docker container
# shellcheck disable=SC2086
docker compose -f $DOCKER_COMPOSE_FILE exec -T python-black-container black --check $(echo $CHANGED_PYTHON_FILES | sed "s| | $REPO_PATH/|g" | sed "s|^|$REPO_PATH/|") --exclude "migrations"
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "Commit failed: Black formatting check did not pass."
  # Show detailed output by running Black again
  # shellcheck disable=SC2086
  docker compose -f $DOCKER_COMPOSE_FILE exec -T python-black-container black $(echo $CHANGED_PYTHON_FILES | sed "s| | $REPO_PATH/|g" | sed "s|^|$REPO_PATH/|") --diff
  exit 1
else
  echo "Black formatting check passed. Proceeding with commit."
  exit 0
fi
