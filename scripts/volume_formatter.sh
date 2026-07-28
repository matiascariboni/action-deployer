#!/bin/bash
set -e

# AT THE MOMENT JUST BIND MOUNTS VOLUMES ARE ALLOWED, NAMED VOLUMES ARE NOT CONTEMPLED

COMPOSE_VOLUMES=""
volume_array=()

while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ ^#\ VOLUME\ (.+) ]]; then
        volume_array+=("$(echo "${BASH_REMATCH[1]}" | tr -d ' ')")
    fi
done < "$DOCKERFILE_PATH"

if [[ ${#volume_array[@]} -gt 0 ]]; then
    COMPOSE_VOLUMES="$(IFS=,; echo "${volume_array[*]}")"
fi

echo "COMPOSE_VOLUMES=$COMPOSE_VOLUMES" >> $GITHUB_OUTPUT
