#!/usr/bin/env bash
set -euo pipefail

METRICS_SERVER_MANIFEST="${METRICS_SERVER_MANIFEST:-https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml}"

if kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1; then
  echo "Metrics API already registered (v1beta1.metrics.k8s.io)."
else
  echo "Installing metrics-server..."
  kubectl apply -f "${METRICS_SERVER_MANIFEST}"
fi

# Kind nodes use self-signed kubelet certs; metrics-server needs this locally.
if kubectl -n kube-system get deploy metrics-server >/dev/null 2>&1; then
  if ! kubectl -n kube-system get deploy metrics-server \
    -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -q 'kubelet-insecure-tls'; then
    echo "Patching metrics-server for Kind (--kubelet-insecure-tls)..."
    kubectl patch deployment metrics-server -n kube-system --type='json' \
      -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
  fi
fi

echo "Waiting for metrics-server..."
kubectl -n kube-system rollout status deploy/metrics-server --timeout=120s

echo "Waiting for Metrics API to become available..."
for i in $(seq 1 30); do
  available="$(kubectl get apiservice v1beta1.metrics.k8s.io -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || true)"
  if [ "${available}" = "True" ]; then
    break
  fi
  sleep 2
done

echo
echo "Metrics API:"
kubectl get apiservice v1beta1.metrics.k8s.io
echo
kubectl top nodes
