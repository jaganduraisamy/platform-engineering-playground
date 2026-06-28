#!/bin/sh
set -eu

CLUSTER_NAME="${CLUSTER_NAME:-home-k8-cluster}"
REGISTRY_NAME="${REGISTRY_NAME:-kind-registry}"
REGISTRY_PORT="${REGISTRY_PORT:-5001}"
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${REGISTRY_PORT}"

if [ "$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null || true)" != "true" ]; then
  docker run -d --restart=always \
    -p "127.0.0.1:${REGISTRY_PORT}:5000" \
    --network bridge \
    --name "${REGISTRY_NAME}" \
    registry:2
fi

if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REGISTRY_NAME}" 2>/dev/null || true)" = 'null' ]; then
  docker network connect kind "${REGISTRY_NAME}"
fi

for node in $(kind get nodes --name "${CLUSTER_NAME}"); do
  docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" tee "${REGISTRY_DIR}/hosts.toml" >/dev/null
[host."http://${REGISTRY_NAME}:5000"]
EOF
done

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo "Kind local registry ready at localhost:${REGISTRY_PORT}"
echo "Use image names like localhost:${REGISTRY_PORT}/otel-kafka-producer:latest"