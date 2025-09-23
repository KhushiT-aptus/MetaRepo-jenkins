#!/bin/bash
set -euo pipefail

SERVER="$1"
REGISTRY="$2"
SERVICE="$3"
TAG="$4"
USERNAME="$5"
PASSWORD="$6"

log() { echo -e "\033[1;34m[DEPLOY]\033[0m $1"; }
error_exit() { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; exit 1; }

log "Deploying $SERVICE:$TAG to $SERVER"

ssh -o StrictHostKeyChecking=no "$SERVER" bash -s <<EOF || error_exit "SSH command failed"
set -euo pipefail

COMPOSE_FILE="/home/aptus/pie-dev-dir/docker-compose.yml"

if [ ! -f "\$COMPOSE_FILE" ]; then
    echo "[REMOTE ERROR] Docker Compose file not found at \$COMPOSE_FILE"
    exit 1
fi

cd /home/aptus/pie-dev-dir

echo "[REMOTE] Logging into Docker registry..."
echo "$PASSWORD" | docker login "$REGISTRY" -u "$USERNAME" --password-stdin

# Update only the deployed service image
echo "[REMOTE] Updating image for $SERVICE to $REGISTRY/$SERVICE:$TAG"
yq e -i ".services.$SERVICE.image = \"$REGISTRY/$SERVICE:$TAG\"" "\$COMPOSE_FILE"

echo "[REMOTE] Pulling updated image for $SERVICE..."
docker compose pull "$SERVICE"

echo "[REMOTE] Starting $SERVICE..."
docker compose up -d --no-deps "$SERVICE"

echo "[REMOTE] Deployment successful!"
EOF

log "Deployment completed for $SERVICE"
