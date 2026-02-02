# Deploying application on an EC2 Instance with Amazon Linux

ERROR_COLOR='\033[0;31m'
WARNING_COLOR="\033[0;33m"
NO_COLOR="\033[0m"
SERVICE_NAME=${IMAGE_NAME%.*}
COMPOSE_IMAGE=$SERVICE_NAME

allChecks() {
    echo "=== Validating inputs ==="
    # Check inputs
    echo "IMAGE_NAME       = $IMAGE_NAME"
    echo "COMPOSE_PORTS    = $COMPOSE_PORTS"
    echo "COMPOSE_NETWORKS = $COMPOSE_NETWORKS"
    echo "COMPOSE_VOLUMES  = $COMPOSE_VOLUMES"
    echo "COMPOSE_FILE_NAME= $COMPOSE_FILE_NAME"
    echo "SERVICE_NAME     = $SERVICE_NAME"
    echo "COMPOSE_IMAGE    = $COMPOSE_IMAGE"

    required_vars=(
    IMAGE_NAME
    COMPOSE_FILE_NAME
    )

    optional_vars=(
    COMPOSE_PORTS
    COMPOSE_NETWORKS
    COMPOSE_VOLUMES
    )

    empty_vars=()
    for var_name in "${required_vars[@]}"; do
        if [ -z "${!var_name}" ]; then
            empty_vars+=("$var_name")
        fi
    done

    if [ ${#empty_vars[@]} -ne 0 ]; then
        echo -e "${ERROR_COLOR}The following required variables are empty:${NO_COLOR}"
        for var in "${empty_vars[@]}"; do
            echo -e "${ERROR_COLOR}- $var${NO_COLOR}"
        done
        exit 1
    fi

    for var_name in "${optional_vars[@]}"; do
        if [ -z "${!var_name+x}" ]; then
            echo -e "${WARNING_COLOR}'$var_name' is not set.${NO_COLOR}"
        fi
    done

    # Check if Docker image has been really transfered
    if [ -f "./$IMAGE_NAME" ]; then
        echo "✅ $IMAGE_NAME detected"
    else
        echo -e "${ERROR_COLOR}❌ $IMAGE_NAME not detected, exiting${NO_COLOR}" >&2
        exit 1
    fi

    # Check if Docker are installed
    if ! command -v docker &>/dev/null; then
        echo -e "${WARNING_COLOR}Docker not detected, installing it${NO_COLOR}"
        sudo yum update -y
        sudo yum install docker -y
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -a -G docker $(whoami)
        echo "✅ Docker installed"
    else
        echo "✅ Docker already installed"
    fi

    # Check if Docker Compose are installed
    if ! command -v docker-compose &>/dev/null; then
        echo -e "${WARNING_COLOR}Docker Compose not detected, installing it${NO_COLOR}"
        sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo "✅ Docker Compose installed"
    else
        echo "✅ Docker Compose already installed"
    fi

    # Check if docker-compose.yml exists
    if [ -f ${COMPOSE_FILE_NAME} ]; then
        echo "✅ ${COMPOSE_FILE_NAME} detected"
    else
        echo -e "${WARNING_COLOR}Docker compose yml file not detected, creating it${NO_COLOR}"
        echo -e "services:" >${COMPOSE_FILE_NAME}
    fi
}

loadDockerImage() {
    echo "=== Loading Docker image ==="
    docker-compose -f $COMPOSE_FILE_NAME down --rmi local
    docker images -q $SERVICE_NAME | xargs docker rmi --force 2>/dev/null || true
    docker load -i $IMAGE_NAME
    [ $? -ne 0 ] && echo -e "${ERROR_COLOR}❌ Failed to load Docker image${NO_COLOR}" && exit 1
    rm -f $IMAGE_NAME
    COMPOSE_IMAGE+=$(printf ":%s" "$(docker images --format "{{.Tag}}" $SERVICE_NAME)")
    echo "✅ Image loaded: $COMPOSE_IMAGE"
}

composeConfig() {
    echo "=== Configuring docker-compose ==="
    # Check if comment flags (START_SERVICE_NAME & END_SERVICE_NAME are created. Case yes, delete all the lines between them and write the new configuration. Case no, insert the new configuration at the end of the file)
    if [[ -n "$COMPOSE_PORTS" ]]; then
        IFS=',' read -ra ports <<<"$COMPOSE_PORTS"
        formatted_ports=$(printf "ports:")
        for port in "${ports[@]}"; do
            formatted_ports+="\n    - \"${port}\""
        done
    else
        formatted_ports=""
    fi

    if [[ -n "$COMPOSE_NETWORKS" ]]; then
        IFS=',' read -ra nets <<<"$COMPOSE_NETWORKS"
        formatted_networks=$(printf "networks:")
        for net in "${nets[@]}"; do
            formatted_networks+="\n    - ${net}"
        done
    else
        formatted_networks=""
    fi

    if [[ -n "$COMPOSE_VOLUMES" ]]; then
        IFS=',' read -ra volumes <<<"$COMPOSE_VOLUMES"
        formatted_volumes=$(printf "volumes:")
        for volume in "${volumes[@]}"; do
            formatted_volumes+="\n    - ${volume}"
        done
    else
        formatted_volumes=""
    fi

    COMPOSE_INSERT="  ${SERVICE_NAME}:
    image: \"${COMPOSE_IMAGE}\"
    container_name: \"${SERVICE_NAME}\""

    # Add networks if they exist
    if [[ "$formatted_networks" != "" ]]; then
        COMPOSE_INSERT="${COMPOSE_INSERT}
        ${formatted_networks}"
    fi

    COMPOSE_INSERT="${COMPOSE_INSERT}
    restart: \"always\""

    # Add ports if they exist
    if [[ "$formatted_ports" != "" ]]; then
        COMPOSE_INSERT="${COMPOSE_INSERT}
        ${formatted_ports}"
    fi

    # Add volumes if they exist
    if [[ "$formatted_volumes" != "" ]]; then
        COMPOSE_INSERT="${COMPOSE_INSERT}
        ${formatted_volumes}"
    fi

    # Insert service configuration
    if grep -q "# START_${SERVICE_NAME}" "$COMPOSE_FILE_NAME" && grep -q "# END_${SERVICE_NAME}" "$COMPOSE_FILE_NAME" && awk "/# START_${SERVICE_NAME}/ {start=NR} /# END_${SERVICE_NAME}/ {end=NR} END {exit start >= end}" "$COMPOSE_FILE_NAME"; then
        # Case config block already created, replace all the config between comment flags
        perl -0777 -i -pe "s|# START_${SERVICE_NAME}.*# END_${SERVICE_NAME}|# START_${SERVICE_NAME}\n$COMPOSE_INSERT\n# END_${SERVICE_NAME}|s" "$COMPOSE_FILE_NAME"
        echo "✅ Updated existing service config"
    else
        # Case config block don't exist, append it at the end of the file
        echo -e "\n# START_${SERVICE_NAME}\n$COMPOSE_INSERT\n# END_${SERVICE_NAME}" >>"$COMPOSE_FILE_NAME"
        echo "✅ Added new service config"
    fi

    # Erasing networks section
    sed -i '/# START_NETWORK/,/# END_NETWORK/d' "$COMPOSE_FILE_NAME"

    # List all networks in compose file
    listed_networks=($(awk '
        /networks:/ {flag=1; next}
        /^[^[:space:]-]/ {flag=0}
        flag && /^[[:space:]]*-[[:space:]]*/ {
        sub(/^[[:space:]]*-[[:space:]]*/, "");
        if ($0 ~ /^[A-Za-z0-9_-]+$/ && !seen[$0]++) print
    }' "$COMPOSE_FILE_NAME" | sort))

    # Re-insert network configuration ONLY if networks exist
    if [[ ${#listed_networks[@]} -eq 0 ]]; then
        echo "No networks to configure"
    else
        formatted_networks=$(printf "networks:")
        for network in "${listed_networks[@]}"; do
            formatted_networks+="\n  ${network}:\n    driver: bridge"
        done
        echo -e "
    # START_NETWORK
    ${formatted_networks}
    # END_NETWORK" >>"$COMPOSE_FILE_NAME"
        echo "✅ Networks configured"
    fi
}

composeFormatter() {
    echo "=== Formatting compose file ==="

    level=(0 2 4 6 8 10 12 14)

    # Setting the pattern spaces dictionary
    declare -A padding_dict=(
        ["^services"]=${level[0]}
        ["^container_name"]=${level[2]}
        ["^image"]=${level[2]}
        ["^restart"]=${level[2]}
        ["^ports"]=${level[2]}
        ["^volumes"]=${level[2]}
        ["^secrets"]=${level[2]}
        ["^environment"]=${level[2]}
        ["^command"]=${level[2]}
        ["^depends_on"]=${level[2]}
        ["^networks"]=${level[2]}
        ["^driver"]=${level[2]}
        ["^links"]=${level[2]}
        ["^healthcheck"]=${level[2]}
        ["^extra_hosts"]=${level[2]}
        ["^deploy"]=${level[2]}
        ["^replicas"]=${level[3]}
        ["^resources"]=${level[3]}
        ["^limits"]=${level[4]}
        ["^cpus"]=${level[5]}
        ["^memory"]=${level[5]}
        ["^restart_policy"]=${level[4]}
        ["^condition"]=${level[5]}
        ["^labels"]=${level[2]}
    )

    temp_file=$(mktemp)

    current_indent=0
    previous_line_was_comment=false

    # Processing docker-compose file
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Delete all starting spaces on each line
        line=$(echo "$line" | sed 's/^[ \t]*//')

        # Delete all empty lines
        if [[ -z "$line" ]]; then
            continue
        fi

        # Case line it's a comment, leave it as it is
        if [[ "$line" =~ ^# ]]; then
            echo "$line" >>"$temp_file"
            previous_line_was_comment=true
            # Check if the comment is the START_NETWORK flag
            if [[ "$line" == "# START_NETWORK" ]]; then
                start_network_flag=true
            fi
            continue
        fi

        padded_line="$line"
        matched_pattern=false

        # Check if line match with some pattern on the dict
        for pattern in "${!padding_dict[@]}"; do
            if [[ "$line" =~ $pattern ]]; then
                # Adjust the level if it is a network line and START_NETWORK flag is set
                if [[ "$pattern" == "^networks" && "$start_network_flag" == true ]]; then
                    padding_left=${level[0]}
                else
                    padding_left=${padding_dict[$pattern]}
                fi

                padded_line=$(printf "%*s" $((${#line} + padding_left)) "$line")
                current_indent=$padding_left
                matched_pattern=true
                break
            fi
        done

        # Case line didn't match with any pattern
        if [ "$matched_pattern" = false ]; then
            if [ "$previous_line_was_comment" = true ]; then
                # Case last line was a commment, it means the line it's a service name, applying identation level 1
                padded_line=$(printf "%*s" $((${#line} + ${level[1]})) "$line")
                current_indent=${level[1]}
            else
                # Case network_flag is true and line don't match with any pattern, is a network name
                if [ "$start_network_flag" = true ]; then
                    padding_left=${level[1]}
                else
                    # Reasing the identation
                    padding_left=$((current_indent + 2))
                fi
                padded_line=$(printf "%*s" $((${#line} + padding_left)) "$line")
            fi
        fi

        echo "$padded_line" >>"$temp_file"
        previous_line_was_comment=false
    done <"$COMPOSE_FILE_NAME"

    # Replace the original file with the new temp file formatted
    mv "$temp_file" "$COMPOSE_FILE_NAME"
    echo "✅ Compose file formatted"
}

dockerNetCleaner() {
    echo "=== Cleaning unused networks ==="
    networks=$(docker network ls --format "{{.Name}}")

    for network in $networks; do
        # Skip predefined Docker networks
        if [[ "$network" == "bridge" || "$network" == "host" || "$network" == "none" ]]; then
            continue
        fi

        # Check if the network has containers connected
        containers=$(docker network inspect "$network" --format '{{range .Containers}}{{.Name}} {{end}}')

        # If there are no containers in the network, delete it
        if [ -z "$containers" ]; then
            echo "Removing '$network'..."
            docker network rm "$network"
        fi
    done
    echo "✅ Network cleanup complete"
}

composeUp() {
    echo "=== Starting containers ==="
    docker-compose -f $COMPOSE_FILE_NAME up -d
    [ $? -ne 0 ] && echo -e "${ERROR_COLOR}❌ Failed to start containers${NO_COLOR}" && exit 1
    echo "✅ Containers started successfully"
}

echo "Starting deployment process..."
allChecks
loadDockerImage
composeConfig
composeFormatter
dockerNetCleaner
composeUp
echo "🎉 Deployment completed!"