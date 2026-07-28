#!/bin/bash
set -e

COMPOSE_NETWORKS=""
net_array=()

while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ ^#\ NETWORK\ (.+) ]]; then
        net_array+=("$(echo "${BASH_REMATCH[1]}" | tr -d ' ' | tr '[:upper:]' '[:lower:]')")
    fi
done < "$DOCKERFILE_PATH"

if [[ ${#net_array[@]} -gt 0 ]]; then
    COMPOSE_NETWORKS="$(IFS=,; echo "${net_array[*]}")"
fi

echo "COMPOSE_NETWORKS=$COMPOSE_NETWORKS" >> $GITHUB_OUTPUT
