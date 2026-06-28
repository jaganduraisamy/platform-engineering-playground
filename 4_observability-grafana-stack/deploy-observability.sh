#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBS_NS="${OBS_NS:-observability}"
APP_NS="${APP_NS:-demo-voting-app}"
KSM_BASE="${KSM_BASE:-https://raw.githubusercontent.com/kubernetes/kube-state-metrics/main/examples/standard}"
GRAFANA_HOST="${GRAFANA_HOST:-grafana.localhost}"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1"
    exit 1
  }
}

require kubectl
require curl

echo "==> Prerequisites"
kubectl config current-context
kubectl -n demo-voting-app get pods
kubectl -n ingress-nginx get pods -l app.kubernetes.io/component=controller

echo
echo "==> Install kube-state-metrics"
for manifest in service-account cluster-role cluster-role-binding service deployment; do
  kubectl apply -f "${KSM_BASE}/${manifest}.yaml"
done
kubectl -n kube-system rollout status deploy/kube-state-metrics --timeout=240s

echo
echo "==> Deploy LGTM stack"
kubectl apply -f "${SCRIPT_DIR}/lgtm-observability-stack.yaml"

for deploy in loki tempo prometheus grafana pyroscope; do
  kubectl -n "${OBS_NS}" rollout status "deploy/${deploy}" --timeout=300s
done
kubectl -n "${OBS_NS}" rollout status daemonset/promtail --timeout=300s

echo
echo "==> Deploy Grafana Ingress"
kubectl apply -f "${SCRIPT_DIR}/02-grafana-ingress.yaml"
kubectl -n "${OBS_NS}" get ingress grafana

echo
echo "==> Validate"
health="000"
for _ in $(seq 1 30); do
  health="$(curl -s -o /dev/null -w "%{http_code}" -u admin:admin -H "Host: ${GRAFANA_HOST}" "http://127.0.0.1/api/health" 2>/dev/null || true)"
  [ "${health}" = "200" ] && break
  sleep 2
done
echo "Grafana via ingress -> HTTP ${health}"

if [ "${health}" != "200" ]; then
  exit 1
fi

echo "OK — http://${GRAFANA_HOST}/ (admin / admin)"
echo "Next: ../5_otel-instrumentation/deploy-otel.sh"
