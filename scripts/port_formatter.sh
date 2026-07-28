#!/bin/bash
set -e

COMPOSE_PORTS=""
ports_array=()

while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ ^EXPOSE[[:space:]]([0-9]+) ]]; then
        last_exposed_port="${BASH_REMATCH[1]}"
    fi

    if [[ $line =~ ^#[[:space:]]TO[[:space:]]([0-9]+) ]]; then
        to_port="${BASH_REMATCH[1]}"
        if [[ -n $last_exposed_port ]]; then
            ports_array+=("${to_port}:${last_exposed_port}")
        fi
    fi
done < "$DOCKERFILE_PATH"

if [[ ${#ports_array[@]} -gt 0 ]]; then
    COMPOSE_PORTS="$(IFS=,; echo "${ports_array[*]}")"
fi

echo "COMPOSE_PORTS=$COMPOSE_PORTS" >> $GITHUB_OUTPUT
