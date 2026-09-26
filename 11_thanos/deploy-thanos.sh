#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBS_NS="${OBS_NS:-observability}"
THANOS_QUERY_HOST="${THANOS_QUERY_HOST:-thanos-query.localhost}"

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
kubectl -n "${OBS_NS}" get deploy/prometheus

echo
echo "==> Deploy MinIO (object storage stand-in) + create bucket"
kubectl apply -f "${SCRIPT_DIR}/minio.yaml"
kubectl -n "${OBS_NS}" rollout status deploy/minio --timeout=180s
kubectl -n "${OBS_NS}" wait --for=condition=complete job/create-thanos-bucket --timeout=120s

echo
echo "==> Deploy Thanos objstore config"
kubectl apply -f "${SCRIPT_DIR}/thanos-objstore-secret.yaml"

echo
echo "==> Patch step 4's Prometheus with the Thanos Sidecar + add the Thanos Query Grafana datasource"
kubectl apply -f "${SCRIPT_DIR}/../4_observability-grafana-stack/lgtm-observability-stack.yaml"
kubectl -n "${OBS_NS}" rollout status deploy/prometheus --timeout=180s
kubectl -n "${OBS_NS}" rollout restart deploy/grafana
kubectl -n "${OBS_NS}" rollout status deploy/grafana --timeout=180s

echo
echo "==> Deploy Store Gateway, Compactor, Querier"
kubectl apply -f "${SCRIPT_DIR}/thanos-stack.yaml"
for deploy in thanos-store-gateway thanos-compactor thanos-query; do
  kubectl -n "${OBS_NS}" rollout status "deploy/${deploy}" --timeout=180s
done

echo
echo "==> Deploy Ingress"
kubectl apply -f "${SCRIPT_DIR}/02-thanos-ingress.yaml"

echo
echo "==> Validate"
health="000"
for _ in $(seq 1 30); do
  health="$(curl -s -o /dev/null -w "%{http_code}" -H "Host: ${THANOS_QUERY_HOST}" "http://127.0.0.1/-/healthy" 2>/dev/null || true)"
  [ "${health}" = "200" ] && break
  sleep 2
done
echo "Thanos Query via ingress -> HTTP ${health}"

if [ "${health}" != "200" ]; then
  exit 1
fi

echo "OK — http://${THANOS_QUERY_HOST}/ (Thanos Query UI)"
echo "MinIO console — http://minio-console.localhost/ (minioadmin / minioadmin)"
echo "Next: Grafana (http://grafana.localhost/) -> Explore -> Thanos Query datasource"
