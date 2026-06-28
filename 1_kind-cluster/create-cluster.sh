#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-home-k8-cluster}"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1"
    exit 1
  }
}

require kind
require kubectl
require docker

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is not running. Start Docker Desktop, Colima, or OrbStack first."
  exit 1
fi

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "Cluster '${CLUSTER_NAME}' already exists."
  echo "Delete it first: kind delete cluster --name ${CLUSTER_NAME}"
  exit 1
fi

echo "Creating kind cluster '${CLUSTER_NAME}'..."
kind create cluster --name "${CLUSTER_NAME}" --config "${SCRIPT_DIR}/kind-config.yaml"

echo
kubectl cluster-info --context "kind-${CLUSTER_NAME}"
echo
kubectl get nodes

echo
"${SCRIPT_DIR}/enable-metrics-server.sh"

echo
echo "Cluster ready. Next: 2_kodekloud-voting-app/ then 3_networking/"
