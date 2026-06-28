#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INGRESS_NS="${INGRESS_NS:-ingress-nginx}"
APP_NS="${APP_NS:-demo-voting-app}"
HOST="${HOST:-demo-vote.localhost}"
HELM_RELEASE="${HELM_RELEASE:-ingress-nginx}"
CHART_VERSION="${CHART_VERSION:-4.12.1}"

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
kubectl -n "${APP_NS}" get svc vote result

echo
echo "==> Helm install ingress-nginx"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update ingress-nginx
helm upgrade --install "${HELM_RELEASE}" ingress-nginx/ingress-nginx \
  --namespace "${INGRESS_NS}" \
  --create-namespace \
  --version "${CHART_VERSION}" \
  -f "${SCRIPT_DIR}/kind-helm-values.yaml"

kubectl -n "${INGRESS_NS}" wait --for=condition=Ready pod \
  -l app.kubernetes.io/component=controller \
  --timeout=180s
kubectl -n "${INGRESS_NS}" get pod -l app.kubernetes.io/component=controller -o wide

echo
echo "==> Deploy app Ingress"
kubectl apply -f "${SCRIPT_DIR}/01-voting-app-ingress.yaml"
kubectl -n "${APP_NS}" get ingress voting-app

echo
echo "==> Validate"
vote_code="$(curl -s -o /dev/null -w "%{http_code}" -H "Host: ${HOST}" http://127.0.0.1/)"
result_code="$(curl -s -o /dev/null -w "%{http_code}" -H "Host: ${HOST}" http://127.0.0.1/result)"
echo "GET /        -> HTTP ${vote_code}"
echo "GET /result  -> HTTP ${result_code}"

if [ "${vote_code}" != "200" ] || [ "${result_code}" != "200" ]; then
  exit 1
fi

echo "OK — http://${HOST}/ and http://${HOST}/result"
