# Ingress NGINX In Front Of The Demo Voting App

This experiment puts `ingress-nginx` in front of the existing KodeKloud demo voting app already running in the kind cluster.

It uses the current cluster design:
- kind control-plane port `80` is mapped to host port `80`
- the voting app already exposes internal Kubernetes Services named `vote` and `result`
- `ingress-nginx` becomes the north-south entry point for those Services

## Purpose

This is the first useful networking experiment because it introduces the common production pattern of:

- app pods behind Services
- one shared ingress controller
- HTTP routing based on host and path
- one stable entry point for users and tests

## Problem This Solves

Without ingress, the demo app is usually accessed with `port-forward`, which is fine for debugging but weak as a platform pattern.

Problems with relying only on `port-forward`:
- it is manual and user specific
- it does not model shared platform entry points
- it does not teach routing or ingress policy
- it does not scale to multiple HTTP apps cleanly

With ingress-nginx, you can expose both app UIs behind one controller and test realistic routing behavior.

## Target Routing

This experiment uses one host and two paths:

- `demo-vote.localhost/` routes to the `vote` Service
- `demo-vote.localhost/result` routes to the `result` Service

This keeps the experiment small while still showing how a platform team publishes multiple app endpoints behind a shared controller.

## Prerequisites

- the kind cluster from [kubernetes/kind-cluster/README.md](kubernetes/kind-cluster/README.md) exists
- the demo app from [kubernetes/kodekloud-voting-app/README.md](kubernetes/kodekloud-voting-app/README.md) is deployed
- your `kubectl` context points to `kind-home-k8-cluster`

Verify the app Services first:

```bash
kubectl config current-context
kubectl -n demo-voting-app get svc vote result
```

## Step 1: Install ingress-nginx For kind

Use the upstream kind-focused install manifest:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

Wait until the controller is ready:

```bash
kubectl -n ingress-nginx wait --for=condition=Ready pod \
  -l app.kubernetes.io/component=controller \
  --timeout=180s
```

Confirm the controller Service exists:

```bash
kubectl -n ingress-nginx get svc
```

Why this works here:
- the kind cluster already maps host ports `80` and `443`
- the control-plane node is already labeled `ingress-ready=true`
- the upstream kind manifest is designed for this exact layout

## Step 2: Apply The App Ingress Manifest

Apply the local manifest in this folder:

```bash
kubectl apply -f 01-voting-app-ingress.yaml
```

Inspect it:

```bash
kubectl -n demo-voting-app get ingress
kubectl -n demo-voting-app describe ingress voting-app
```

## Step 3: Test Routing

For browser access, add the host mapping first:

```bash
echo "127.0.0.1 demo-vote.localhost" | sudo tee -a /etc/hosts
```

Then open the app in your browser:

- http://demo-vote.localhost/
- http://demo-vote.localhost/result

If you just want a quick terminal check, you can still send the `Host` header manually.

Vote UI:

```bash
curl -H "Host: demo-vote.local" http://127.0.0.1/
curl -H "Host: demo-vote.localhost" http://127.0.0.1/
```

Result UI:

```bash
curl -H "Host: demo-vote.local" http://127.0.0.1/result
curl -H "Host: demo-vote.localhost" http://127.0.0.1/result
```

## Manifest Notes

The manifest uses:
- `ingressClassName: nginx` so the intent is explicit
- path prefix matching so `/result` reaches the result UI
- a rewrite annotation so the backend sees `/` instead of `/result`

That keeps the routing simple while still demonstrating one real ingress controller feature.

## Troubleshooting

If the ingress does not work, check in this order.

### 1. Is The Controller Running?

```bash
kubectl -n ingress-nginx get pods
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller
```

Likely issue:
- ingress controller pods are not ready yet

### 2. Did The Ingress Get Accepted?

```bash
kubectl -n demo-voting-app describe ingress voting-app
kubectl get ingressclass
```

Likely issues:
- wrong ingress class
- syntax or path mismatch in the manifest

### 3. Do The Backend Services Have Endpoints?

```bash
kubectl -n demo-voting-app get svc vote result
kubectl -n demo-voting-app get endpoints vote result
kubectl -n demo-voting-app get pods -o wide
```

Likely issues:
- Services exist but no matching pods are ready
- app pods crashed or are still starting

### 4. Is Host Port 80 Reaching kind?

```bash
kubectl get nodes -o wide
curl -I -H "Host: demo-vote.local" http://127.0.0.1/
```

Likely issues:
- another local process is using port `80`
- the kind cluster was created from a different config without port mappings

### 5. Does The Path Rewrite Behave As Expected?

```bash
curl -H "Host: demo-vote.local" http://127.0.0.1/result -v
```

Likely issue:
- if the backend app expects `/`, the rewrite annotation must stay in place

## Cleanup

Remove only the ingress object:

```bash
kubectl delete -f 01-voting-app-ingress.yaml
```

Remove the controller too:

```bash
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

## Why This Matters For Platform Engineering

This experiment teaches the split between:
- platform-owned edge entry point
- application-owned Service destinations
- operational debugging between external traffic and internal workloads

That split is the foundation you will later compare against Gateway API and Istio.