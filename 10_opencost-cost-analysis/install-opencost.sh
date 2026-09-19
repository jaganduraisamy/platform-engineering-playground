#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-opencost}"
HELM_RELEASE="${HELM_RELEASE:-opencost}"
HOST="${HOST:-opencost.localhost}"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1"
    exit 1
  }
}

require kubectl
require helm
require curl

echo "==> Prerequisites"
kubectl config current-context
kubectl -n observability get svc prometheus

echo
echo "==> Helm install opencost"
helm repo add opencost https://opencost.github.io/opencost-helm-chart >/dev/null 2>&1 || true
helm repo update opencost
helm upgrade --install "${HELM_RELEASE}" opencost/opencost \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  -f "${SCRIPT_DIR}/opencost-values.yaml"

kubectl -n "${NAMESPACE}" wait --for=condition=available --timeout=300s deployment --all
kubectl -n "${NAMESPACE}" get pods -o wide

echo
echo "==> Validate"
ui_code="$(curl -s -o /dev/null -w "%{http_code}" -H "Host: ${HOST}" http://127.0.0.1/)"
echo "GET /  -> HTTP ${ui_code}"

if [ "${ui_code}" != "200" ]; then
  exit 1
fi

echo "OK — http://${HOST}"
