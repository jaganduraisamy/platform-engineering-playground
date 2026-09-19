#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-opencost}"
HELM_RELEASE="${HELM_RELEASE:-opencost}"

helm uninstall "${HELM_RELEASE}" -n "${NAMESPACE}" 2>/dev/null || true
kubectl delete namespace "${NAMESPACE}" --ignore-not-found --wait=true --timeout=120s

echo "opencost removed"
