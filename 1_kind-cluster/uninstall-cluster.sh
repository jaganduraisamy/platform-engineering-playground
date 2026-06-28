#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-home-k8-cluster}"

kind delete cluster --name "${CLUSTER_NAME}" 2>/dev/null || true
echo "cluster '${CLUSTER_NAME}' removed"
