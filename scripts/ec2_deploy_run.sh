# Swapping a service's running container for the already-delivered image on an EC2 Instance
# Assumes a previous DELIVER run already loaded the new image and prepared $COMPOSE_FILE_NAME.

ERROR_COLOR='\033[0;31m'
WARNING_COLOR="\033[0;33m"
NO_COLOR="\033[0m"

echo "=== Validating environment ==="
echo "COMPOSE_FILE_NAME= $COMPOSE_FILE_NAME"
echo "SERVICE_NAME     = $SERVICE_NAME"

if [ -z "$COMPOSE_FILE_NAME" ] || [ -z "$SERVICE_NAME" ]; then
    echo -e "${ERROR_COLOR}❌ COMPOSE_FILE_NAME and SERVICE_NAME are required${NO_COLOR}"
    exit 1
fi

if ! command -v docker-compose &>/dev/null; then
    echo -e "${ERROR_COLOR}❌ docker-compose not found on this host. Run a DELIVER action first.${NO_COLOR}"
    exit 1
fi

if [ ! -f "$COMPOSE_FILE_NAME" ]; then
    echo -e "${ERROR_COLOR}❌ ${COMPOSE_FILE_NAME} not found on this host. Run a DELIVER action first.${NO_COLOR}"
    exit 1
fi

echo "✅ Environment ready"

echo "=== Swapping container ==="
OLD_CONTAINER_ID=$(docker-compose -f $COMPOSE_FILE_NAME ps -q $SERVICE_NAME 2>/dev/null)
OLD_IMAGE_ID=""
if [ -n "$OLD_CONTAINER_ID" ]; then
    OLD_IMAGE_ID=$(docker inspect --format='{{.Image}}' "$OLD_CONTAINER_ID" 2>/dev/null)
fi

docker-compose -f $COMPOSE_FILE_NAME up -d --no-deps --force-recreate $SERVICE_NAME
[ $? -ne 0 ] && echo -e "${ERROR_COLOR}❌ Failed to start containers${NO_COLOR}" && exit 1
echo "✅ Containers started successfully"

NEW_CONTAINER_ID=$(docker-compose -f $COMPOSE_FILE_NAME ps -q $SERVICE_NAME 2>/dev/null)
NEW_IMAGE_ID=$(docker inspect --format='{{.Image}}' "$NEW_CONTAINER_ID" 2>/dev/null)

if [ -n "$OLD_IMAGE_ID" ] && [ "$OLD_IMAGE_ID" != "$NEW_IMAGE_ID" ]; then
    echo "Removing old image ($OLD_IMAGE_ID)..."
    docker rmi "$OLD_IMAGE_ID" 2>/dev/null || echo -e "${WARNING_COLOR}Could not remove old image (may still be referenced elsewhere)${NO_COLOR}"
fi

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

dockerNetCleaner
echo "🎉 Deployment completed!"
