# Step 1: kind 3-Node Kubernetes Cluster

This folder sets up a local Kubernetes cluster with `kind` (Kubernetes IN Docker).

Cluster layout:
- 1 control-plane node (ingress-ready, host ports 80/443 mapped)
- 2 worker nodes

## Tools To Install First

1. A container runtime: Docker Desktop, Colima, or OrbStack
2. `kubectl`
3. `kind`

### Homebrew

```bash
brew install kind kubectl
```

For Colima instead of Docker Desktop:

```bash
brew install colima docker
colima start --cpu 6 --memory 12 --disk 60
```

## Verify Prerequisites

```bash
kind version
kubectl version --client
docker version
```

## Create The Cluster

From this folder:

```bash
chmod +x create-cluster.sh
./create-cluster.sh
```

Or manually:

```bash
kind create cluster --name home-k8-cluster --config kind-config.yaml
```

## Verify

```bash
kubectl cluster-info --context kind-home-k8-cluster
kubectl get nodes
```

You should see 3 nodes.

## Metrics API (metrics-server)

Kind does not ship **metrics-server** by default. Without it, `kubectl top` and CPU/memory HPA do not work.

`create-cluster.sh` runs `enable-metrics-server.sh` automatically after the cluster is up. To install or re-run on an existing cluster:

```bash
./enable-metrics-server.sh
```

**Why kubectl apply, not Helm?** metrics-server is a single upstream manifest with one Kind-specific patch (`--kubelet-insecure-tls`). Helm adds chart repo/version overhead without benefit for this lab. Use Helm when you need value overrides, multiple environments, or lifecycle hooks.

This is separate from **kube-state-metrics** in step 4 — that component feeds Prometheus object-state metrics (`kube_deployment_*`); it does not register the Kubernetes Metrics API.

Verify:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
kubectl top pods -A
```

## Delete

```bash
./uninstall-cluster.sh
```

Or manually:

```bash
kind delete cluster --name home-k8-cluster
```

## Next Step

Deploy the demo app: [../2_kodekloud-voting-app/README.md](../2_kodekloud-voting-app/README.md)

## Notes

- Local development cluster only, not production.
- Host ports `80` and `443` are mapped for ingress experiments in step 3.
- If those ports are in use, change `hostPort` values in `kind-config.yaml`.
