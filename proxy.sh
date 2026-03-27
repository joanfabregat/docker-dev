#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTAINER_NAME="dev-proxy"
IMAGE="traefik:v3"
NETWORKS=(sophos-network dtpdf-network)

case "${1:-start}" in
  start)
    # Remove existing container if stopped
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
      echo "Container ${CONTAINER_NAME} already exists."
      if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "It's already running."
        exit 0
      fi
      echo "Starting existing container..."
      docker start "${CONTAINER_NAME}"
      exit 0
    fi

    # Ensure networks exist
    for net in "${NETWORKS[@]}"; do
      docker network inspect "$net" >/dev/null 2>&1 || \
        docker network create "$net"
    done

    # Run container with the first network
    docker run -d \
      --name "${CONTAINER_NAME}" \
      --restart always \
      -p 80:80 \
      -p 443:443 \
      -v /var/run/docker.sock:/var/run/docker.sock:ro \
      -v "${SCRIPT_DIR}/config/dynamic.yaml:/etc/traefik/dynamic.yaml:ro" \
      -v "${SCRIPT_DIR}/config/certs:/certs:ro" \
      -v "${SCRIPT_DIR}/config/kubeconfig:/etc/traefik/kubeconfig:ro" \
      -e KUBECONFIG=/etc/traefik/kubeconfig \
      -l traefik.enable=true \
      -l "traefik.http.routers.traefik-dashboard.rule=Host(\`traefik.dev.ffwip.com\`)" \
      -l traefik.http.routers.traefik-dashboard.tls=true \
      -l traefik.http.routers.traefik-dashboard.service=api@internal \
      --network "${NETWORKS[0]}" \
      "${IMAGE}" \
      --entrypoints.web.address=:80 \
      --entrypoints.websecure.address=:443 \
      --entrypoints.web.http.redirections.entryPoint.to=websecure \
      --entrypoints.websecure.http.tls=true \
      --providers.docker=true \
      --providers.docker.exposedByDefault=false \
      --providers.file.filename=/etc/traefik/dynamic.yaml \
      --providers.kubernetesingress=true \
      --providers.kubernetesingress.ingressclass=traefik-dev \
      --api.dashboard=true

    # Connect additional networks
    for net in "${NETWORKS[@]:1}"; do
      docker network connect "$net" "${CONTAINER_NAME}"
    done

    echo "dev-proxy started."
    ;;

  stop)
    docker stop "${CONTAINER_NAME}"
    echo "dev-proxy stopped."
    ;;

  restart)
    docker restart "${CONTAINER_NAME}"
    echo "dev-proxy restarted."
    ;;

  rm)
    docker rm -f "${CONTAINER_NAME}"
    echo "dev-proxy removed."
    ;;

  logs)
    docker logs -f "${CONTAINER_NAME}"
    ;;

  *)
    echo "Usage: $0 {start|stop|restart|rm|logs}"
    exit 1
    ;;
esac
