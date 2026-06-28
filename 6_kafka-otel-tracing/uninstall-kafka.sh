#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOVE_REGISTRY="${REMOVE_REGISTRY:-false}"

kubectl delete -f "${SCRIPT_DIR}/manifests/03-consumer-deployment.yaml" --ignore-not-found
kubectl delete -f "${SCRIPT_DIR}/manifests/02-producer-deployment.yaml" --ignore-not-found
kubectl delete -f "${SCRIPT_DIR}/manifests/05-otel-auto-instrumentation.yaml" --ignore-not-found
kubectl delete -f "${SCRIPT_DIR}/manifests/01-kafka-kraft.yaml" --ignore-not-found
kubectl delete -f "${SCRIPT_DIR}/manifests/00-otel-collector.yaml" --ignore-not-found
kubectl delete namespace otel-kafka-poc --ignore-not-found

if [ "${REMOVE_REGISTRY}" = "true" ]; then
  docker rm -f kind-registry 2>/dev/null || true
fi

echo "kafka otel tracing stack removed"
