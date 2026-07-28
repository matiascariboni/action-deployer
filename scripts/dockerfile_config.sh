#!/bin/bash
set -e

if [ "$REQUIRE_DOCKERFILE" != "false" ]; then
  RESOLVED_DOCKERFILE_PATH="./${DOCKERFILE_PATH}"
  if [[ ! -f "$RESOLVED_DOCKERFILE_PATH" ]]; then
    echo "::error::Dockerfile not found: $RESOLVED_DOCKERFILE_PATH"
    exit 1
  fi
fi

if [ -z "$COMPOSE_NAME" ]; then
  COMPOSE_NAME="${GITHUB_REPOSITORY#*/}"
  echo "COMPOSE_NAME not provided, using repository name: $COMPOSE_NAME"
fi

COMPOSE_FILE_NAME="${COMPOSE_NAME}.yml"
echo "COMPOSE_FILE_NAME=$COMPOSE_FILE_NAME" >> $GITHUB_OUTPUT
