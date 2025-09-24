#!/bin/bash

SERVER="$1"
REGISTRY="$2"
IMAGE="$3"
TAG="$4"
DOCKER_USER="$5"
DOCKER_PASS="$6"

echo "[DEPLOY] Deploying ${IMAGE}:${TAG} to ${SERVER}"

# Login to Docker non-interactively
echo "${DOCKER_PASS}" | docker login "${REGISTRY}" -u "${DOCKER_USER}" --password-stdin

# Pull and run the Docker image
docker pull "${IMAGE}:${TAG}"
docker stop ${IMAGE##*/} || true
docker rm ${IMAGE##*/} || true
docker run -d --name ${IMAGE##*/} "${IMAGE}:${TAG}"

echo "[DEPLOY] Deployment completed!"
