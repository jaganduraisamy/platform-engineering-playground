# kind 3-Node Kubernetes Cluster

This folder sets up a local Kubernetes cluster with `kind`.

`kind` means `Kubernetes IN Docker`. The Kubernetes nodes run as Docker containers.

For a 3-node cluster here, you will create:
- 1 control-plane node
- 2 worker nodes

This setup is meant to be comfortable for learning, testing manifests, running sample apps, and later adding ingress.

## Tools To Install First

Install these before creating the cluster:

1. A container runtime
  - On macOS, use one of these:
  - Docker Desktop
  - Colima
  - OrbStack
2. `kubectl`
3. `kind`

You do not need to create VMs for Kubernetes nodes manually. `kind` creates node containers for you. On macOS, your container runtime may use its own internal Linux VM, but that is managed by the runtime.

## Install Commands

### Option 1: Homebrew

```bash
brew install kind kubectl
```

Then install and start one container runtime:

- Docker Desktop: install from Docker and start the app
- Colima:

```bash
brew install colima docker
colima start --cpu 6 --memory 12 --disk 60
```

What this Colima command does:
- starts one Colima-managed Linux VM on your Mac
- gives that VM 6 vCPUs, 12 GB RAM, and 60 GB disk
- provides the container runtime that `kind` will use

This does not create Kubernetes yet. The Kubernetes nodes are created later by `kind` as containers inside the Colima VM.

- OrbStack: install the app and start it

## Verify Prerequisites

Run these commands:

```bash
kind version
kubectl version --client
docker version
```

Expected result:
- `kind` prints a version
- `kubectl` prints a client version
- `docker version` works without daemon errors

## Create The 3-Node Cluster

From this folder, run:

```bash
kind create cluster --name home-k8-cluster --config kind-config.yaml
```

The cluster name in `kind-config.yaml` is also `home-k8-cluster`, so create, verify, and delete commands stay consistent.

This cluster config also maps these ports from the control-plane node to your Mac:
- `80` for HTTP
- `443` for HTTPS

That makes later ingress and app exposure easier during study and testing.

## Verify The Cluster

```bash
kubectl cluster-info --context kind-home-k8-cluster
kubectl get nodes
```

You should see 3 nodes total.

## Delete The Cluster

```bash
kind delete cluster --name home-k8-cluster
```

## Notes

- This is a local development cluster, not a production cluster.
- LoadBalancer services do not behave like a cloud provider by default.
- If Docker is not running, cluster creation will fail.
- This config already includes host port mappings for `80` and `443`.
- If port `80` or `443` is already in use on your Mac, cluster creation may fail. In that case, change the host ports in `kind-config.yaml`.
