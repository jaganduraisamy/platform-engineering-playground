#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="${1:-}"

if [ -z "${ENV_NAME}" ]; then
  for e in dev uat prod; do
    kubectl delete -k "${SCRIPT_DIR}/kustomize/overlays/${e}" --ignore-not-found 2>/dev/null || true
  done
  echo "welcome-webapp overlays removed (dev, uat, prod)"
  exit 0
fi

case "${ENV_NAME}" in
  dev|uat|prod)
    kubectl delete -k "${SCRIPT_DIR}/kustomize/overlays/${ENV_NAME}" --ignore-not-found
    echo "welcome-webapp overlay removed: ${ENV_NAME}"
    ;;
  *)
    echo "Usage: $0 [dev|uat|prod]"
    echo "Omit env to remove all overlays."
    exit 1
    ;;
esac
