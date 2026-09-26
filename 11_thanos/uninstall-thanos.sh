#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl delete -f "${SCRIPT_DIR}/02-thanos-ingress.yaml" --ignore-not-found
kubectl delete -f "${SCRIPT_DIR}/thanos-stack.yaml" --ignore-not-found
kubectl delete -f "${SCRIPT_DIR}/thanos-objstore-secret.yaml" --ignore-not-found
kubectl delete -f "${SCRIPT_DIR}/minio.yaml" --ignore-not-found

echo "Thanos layer removed (Store Gateway, Compactor, Querier, MinIO)"
echo "Note: the thanos-sidecar container patched into step 4's Prometheus pod is left in place (additive, like step 10's OpenCost edits to step 4)."
echo "  It will CrashLoopBackOff now that MinIO/the objstore Secret are gone — harmless to Prometheus itself, but noisy."
echo "  Full revert: git checkout -- ../4_observability-grafana-stack/lgtm-observability-stack.yaml && (cd ../4_observability-grafana-stack && ./deploy-observability.sh)"
