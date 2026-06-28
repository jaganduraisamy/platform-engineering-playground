#!/usr/bin/env bash
set -euo pipefail

INGRESS_NS="${INGRESS_NS:-ingress-nginx}"

helm uninstall ingress-nginx -n "${INGRESS_NS}" 2>/dev/null || true
kubectl delete namespace "${INGRESS_NS}" --ignore-not-found --wait=true --timeout=120s
kubectl delete clusterrole,clusterrolebinding ingress-nginx,ingress-nginx-admission --ignore-not-found
kubectl delete ingressclass nginx --ignore-not-found
kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found

echo "ingress-nginx removed"
