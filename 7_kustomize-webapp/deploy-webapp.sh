#!/usr/bin/env bash
# Build one image, load into Kind, apply a Kustomize overlay (dev|uat|prod).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="${1:-dev}"
CLUSTER_NAME="${CLUSTER_NAME:-home-k8-cluster}"
IMAGE="welcome-webapp:local"

case "${ENV_NAME}" in
  dev|uat|prod) ;;
  *)
    echo "Usage: $0 <dev|uat|prod>"
    exit 1
    ;;
esac

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1"
    exit 1
  }
}

require docker
require kind
require kubectl

OVERLAY="${SCRIPT_DIR}/kustomize/overlays/${ENV_NAME}"

echo "==> Build image once: ${IMAGE}"
docker build -t "${IMAGE}" "${SCRIPT_DIR}/app"

echo "==> Load image into Kind (${CLUSTER_NAME})"
kind load docker-image "${IMAGE}" --name "${CLUSTER_NAME}"

echo "==> Apply Kustomize overlay: ${ENV_NAME}"
kubectl apply -k "${OVERLAY}"
kubectl -n "welcome-${ENV_NAME}" rollout status deploy/welcome-webapp --timeout=120s

echo
echo "OK — env=${ENV_NAME}"
echo "Port-forward: kubectl -n welcome-${ENV_NAME} port-forward svc/welcome-webapp 8080:80"
echo "Then open http://localhost:8080"
echo
echo "Note: same image tag for all envs; overlay only changes ENV_NAME / BG_COLOR / GREETING."
