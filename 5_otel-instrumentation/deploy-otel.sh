#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBS_NS="${OBS_NS:-observability}"
APP_NS="${APP_NS:-demo-voting-app}"
HELM_RELEASE="${HELM_RELEASE:-otel-operator}"
CHART_VERSION="${CHART_VERSION:-0.117.0}"
INSTRUMENTATION="${INSTRUMENTATION:-demo-auto-instrumentation}"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1"
    exit 1
  }
}

require kubectl
require helm

echo "==> Prerequisites"
kubectl config current-context
kubectl -n "${OBS_NS}" get deploy grafana tempo
kubectl -n "${APP_NS}" get deploy vote result worker

echo
echo "==> Helm install OpenTelemetry Operator"
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
helm repo update open-telemetry
helm upgrade --install "${HELM_RELEASE}" open-telemetry/opentelemetry-operator \
  --namespace "${OBS_NS}" \
  --create-namespace \
  --version "${CHART_VERSION}" \
  --disable-openapi-validation \
  -f "${SCRIPT_DIR}/otel-helm-values.yaml"

kubectl -n "${OBS_NS}" rollout status deploy/"${HELM_RELEASE}"-opentelemetry-operator --timeout=240s
kubectl get crd | grep opentelemetry.io

# Helm upgrades can leave a stale leader lease on the deleted pod; block reconciliation.
holder="$(kubectl -n "${OBS_NS}" get lease 9f7554c3.opentelemetry.io -o jsonpath='{.spec.holderIdentity}' 2>/dev/null || true)"
if [ -n "${holder}" ] && ! kubectl -n "${OBS_NS}" get pod "${holder%%_*}" >/dev/null 2>&1; then
  kubectl -n "${OBS_NS}" delete lease 9f7554c3.opentelemetry.io --ignore-not-found
  sleep 5
fi

echo "Waiting for admission webhook..."
for _ in $(seq 1 90); do
  ready="$(kubectl -n "${OBS_NS}" get endpoints "${HELM_RELEASE}-opentelemetry-operator-webhook" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true)"
  [ -n "${ready}" ] && break
  sleep 2
done
sleep 5

echo
echo "==> Deploy OTel collector + Instrumentation CRs"
for _ in $(seq 1 10); do
  if kubectl apply -f "${SCRIPT_DIR}/otel-auto-instrumentation.yaml"; then
    break
  fi
  sleep 5
done

kubectl -n "${OBS_NS}" wait --for=jsonpath='{.status.scale.statusReplicas}'=1 deploy/otel-gateway-collector --timeout=240s 2>/dev/null \
  || kubectl -n "${OBS_NS}" rollout status deploy/otel-gateway-collector --timeout=240s

echo
echo "==> Enable auto-instrumentation on demo app workloads"
# vote=python, result=nodejs, worker=dotnet (redis/db have no operator injectors)
kubectl -n "${APP_NS}" patch deployment vote --type merge -p \
  '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-python":"'"${INSTRUMENTATION}"'"}}}}}'
kubectl -n "${APP_NS}" patch deployment result --type merge -p \
  '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-nodejs":"'"${INSTRUMENTATION}"'"}}}}}'
kubectl -n "${APP_NS}" patch deployment worker --type merge -p \
  '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-dotnet":"'"${INSTRUMENTATION}"'"}}}}}'

kubectl -n "${APP_NS}" rollout restart deployment vote result worker
kubectl -n "${APP_NS}" rollout status deployment vote --timeout=240s
kubectl -n "${APP_NS}" rollout status deployment result --timeout=240s
kubectl -n "${APP_NS}" rollout status deployment worker --timeout=240s

echo
echo "==> Validate"
kubectl -n "${OBS_NS}" get deploy otel-gateway-collector
kubectl -n "${APP_NS}" get pods
echo "OK — Grafana: http://grafana.localhost/ | traces in Grafana → Explore → Tempo"
