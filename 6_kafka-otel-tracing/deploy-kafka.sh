#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${REGISTRY:-localhost:5001}"
NAMESPACE="${NAMESPACE:-otel-kafka-poc}"
PRODUCER_IMAGE="${REGISTRY}/otel-kafka-producer:latest"
CONSUMER_IMAGE="${REGISTRY}/otel-kafka-consumer:latest"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1"
    exit 1
  }
}

require kubectl
require docker
require curl

echo "==> Prerequisites"
kubectl config current-context
kubectl -n observability get deploy tempo
kubectl get crd instrumentations.opentelemetry.io >/dev/null

echo
echo "==> Setup local registry"
chmod +x "${SCRIPT_DIR}/scripts/setup-kind-registry.sh"
"${SCRIPT_DIR}/scripts/setup-kind-registry.sh"

echo
echo "==> Build and push images"
docker build -t "${PRODUCER_IMAGE}" "${SCRIPT_DIR}/producer-java"
docker build -t "${CONSUMER_IMAGE}" "${SCRIPT_DIR}/consumer-python"
docker push "${PRODUCER_IMAGE}"
docker push "${CONSUMER_IMAGE}"
curl -s "http://${REGISTRY}/v2/_catalog"

echo
echo "==> Deploy Kafka + OTel collector"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "${SCRIPT_DIR}/manifests/00-otel-collector.yaml"
kubectl apply -f "${SCRIPT_DIR}/manifests/01-kafka-kraft.yaml"
kubectl apply -f "${SCRIPT_DIR}/manifests/05-otel-auto-instrumentation.yaml"
kubectl -n "${NAMESPACE}" rollout status deploy/otel-collector --timeout=300s
kubectl -n "${NAMESPACE}" rollout status deploy/kafka --timeout=300s

kubectl apply -f "${SCRIPT_DIR}/manifests/02-producer-deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/manifests/03-consumer-deployment.yaml"
kubectl -n "${NAMESPACE}" rollout status deploy/kafka-producer --timeout=300s
kubectl -n "${NAMESPACE}" rollout status deploy/kafka-consumer --timeout=300s

echo
echo "==> Validate"
kubectl -n "${NAMESPACE}" get pods
kubectl logs -n "${NAMESPACE}" deploy/kafka-producer --tail=5
kubectl logs -n "${NAMESPACE}" deploy/kafka-consumer --tail=5
echo "OK — check traces in http://grafana.localhost/ → Explore → Tempo"
