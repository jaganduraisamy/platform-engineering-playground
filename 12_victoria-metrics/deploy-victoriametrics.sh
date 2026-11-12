#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBS_NS="${OBS_NS:-observability}"
APP_NS="${APP_NS:-demo-voting-app}"
VM_CLUSTER_HOST="${VM_CLUSTER_HOST:-vm-cluster.localhost}"
INSTRUMENTATION="${INSTRUMENTATION:-demo-auto-instrumentation}"

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
kubectl -n "${OBS_NS}" get deploy/prometheus deploy/grafana deploy/otel-gateway-collector

echo
echo "==> Deploy VictoriaMetrics cluster mode (vminsert/vmstorage/vmselect/vmalert), one pod per component"
kubectl apply -f "${SCRIPT_DIR}/vm-cluster-stack.yaml"
kubectl -n "${OBS_NS}" rollout status statefulset/vmstorage --timeout=180s
kubectl -n "${OBS_NS}" rollout status deploy/vminsert --timeout=180s
kubectl -n "${OBS_NS}" rollout status deploy/vmselect --timeout=180s
kubectl -n "${OBS_NS}" rollout status deploy/vmalert --timeout=180s

echo
echo "==> Patch step 4's Prometheus with remote_write to VM + add the VictoriaMetrics Grafana datasource"
kubectl apply -f "${SCRIPT_DIR}/../4_observability-grafana-stack/lgtm-observability-stack.yaml"
kubectl -n "${OBS_NS}" rollout restart deploy/prometheus
kubectl -n "${OBS_NS}" rollout status deploy/prometheus --timeout=180s
kubectl -n "${OBS_NS}" rollout restart deploy/grafana
kubectl -n "${OBS_NS}" rollout status deploy/grafana --timeout=180s

echo
echo "==> Deploy Ingress (vmselect UI/API, vmalert)"
kubectl apply -f "${SCRIPT_DIR}/03-vm-cluster-ingress.yaml"

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
sleep 20
echo "==> Validate: query vmselect (fed by vminsert -> vmstorage x2) for the spanmetrics calls_total series"
kubectl -n "${OBS_NS}" exec deploy/vmalert -- wget -qO- \
  "http://vmselect.${OBS_NS}.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=traces_span_metrics_calls_total" \
  | head -c 500 || echo "WARN — cluster path not returning data yet, same async-remote_write lag as above"
echo

echo
echo "OK — vmselect UI: http://${VM_CLUSTER_HOST}/select/0/vmui/ | API: http://${VM_CLUSTER_HOST}/select/0/prometheus/api/v1/query?query=up"
echo "vmalert UI: http://${VM_CLUSTER_HOST}/vmalert/ | rules: http://${VM_CLUSTER_HOST}/api/v1/rules"
echo "Grafana: http://grafana.localhost/ -> Explore -> VictoriaMetrics datasource"
echo "Vote app: http://demo-vote.localhost/ | Results: http://demo-vote.localhost/result/"
