#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBS_NS="${OBS_NS:-observability}"
APP_NS="${APP_NS:-demo-voting-app}"
HELM_RELEASE="${HELM_RELEASE:-vmsingle}"
VM_HOST="${VM_HOST:-vm.localhost}"
INSTRUMENTATION="${INSTRUMENTATION:-demo-auto-instrumentation}"

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
kubectl -n "${OBS_NS}" get deploy/prometheus deploy/grafana deploy/otel-gateway-collector

echo
echo "==> Helm install VictoriaMetrics (single-node)"
helm repo add victoria-metrics https://victoriametrics.github.io/helm-charts/ >/dev/null 2>&1 || true
helm repo update victoria-metrics
helm upgrade --install "${HELM_RELEASE}" victoria-metrics/victoria-metrics-single \
  --namespace "${OBS_NS}" \
  -f "${SCRIPT_DIR}/vm-helm-values.yaml"
kubectl -n "${OBS_NS}" rollout status statefulset/vmsingle --timeout=180s

echo
echo "==> Patch step 4's Prometheus with remote_write to VM + add the VictoriaMetrics Grafana datasource"
kubectl apply -f "${SCRIPT_DIR}/../4_observability-grafana-stack/lgtm-observability-stack.yaml"
kubectl -n "${OBS_NS}" rollout restart deploy/prometheus
kubectl -n "${OBS_NS}" rollout status deploy/prometheus --timeout=180s
kubectl -n "${OBS_NS}" rollout restart deploy/grafana
kubectl -n "${OBS_NS}" rollout status deploy/grafana --timeout=180s

echo
echo "==> Deploy Ingress (VictoriaUI / API)"
kubectl apply -f "${SCRIPT_DIR}/02-vm-ingress.yaml"

echo
echo "==> Deploy demo voting app (traces/spanmetrics source) + enable OTel auto-instrumentation"
kubectl apply -f "${SCRIPT_DIR}/../2_kodekloud-voting-app/deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/../3_networking/ingress-nginx/01-voting-app-ingress.yaml"

# vote=python, result=nodejs, worker=dotnet — same instrumentation CR 5_otel-instrumentation/ already installed
kubectl -n "${APP_NS}" patch deployment vote --type merge -p \
  '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-python":"'"${INSTRUMENTATION}"'"}}}}}'
kubectl -n "${APP_NS}" patch deployment result --type merge -p \
  '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-nodejs":"'"${INSTRUMENTATION}"'"}}}}}'
kubectl -n "${APP_NS}" patch deployment worker --type merge -p \
  '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-dotnet":"'"${INSTRUMENTATION}"'"}}}}}'

kubectl -n "${APP_NS}" rollout status deployment/redis --timeout=180s
kubectl -n "${APP_NS}" rollout status deployment/db --timeout=180s
kubectl -n "${APP_NS}" rollout status deployment/vote --timeout=180s
kubectl -n "${APP_NS}" rollout status deployment/result --timeout=180s
kubectl -n "${APP_NS}" rollout status deployment/worker --timeout=180s

echo
echo "==> Generate traffic so spans/spanmetrics actually flow"
"${SCRIPT_DIR}/generate-traffic.sh"

echo
echo "==> Validate: query VM directly for the spanmetrics connector's calls_total series"
sleep 20
result="$(curl -s -H "Host: ${VM_HOST}" "http://127.0.0.1/api/v1/query?query=traces_span_metrics_calls_total" || true)"
echo "${result}" | head -c 500
echo
if echo "${result}" | grep -q '"result":\[\]'; then
  echo "WARN — no traces_span_metrics_calls_total series in VM yet; scrape_interval is 15s, remote_write is async, wait ~30s and re-query:"
  echo "  curl -H \"Host: ${VM_HOST}\" \"http://127.0.0.1/api/v1/query?query=traces_span_metrics_calls_total\""
fi

echo
echo "OK — VictoriaUI: http://${VM_HOST}/vmui/ | API: http://${VM_HOST}/api/v1/query?query=up"
echo "Grafana: http://grafana.localhost/ -> Explore -> VictoriaMetrics datasource"
echo "Vote app: http://demo-vote.localhost/ | Results: http://demo-vote.localhost/result/"
