# Step 3: Ingress NGINX for the Demo Voting App

Expose the voting app through a shared ingress controller instead of `port-forward`.

**Routing:**
- `http://demo-vote.localhost/` → `vote` Service
- `http://demo-vote.localhost/result` → `result` Service

## Prerequisites

- Cluster: [../../1_kind-cluster/](../../1_kind-cluster/)
- Demo app deployed: [../../2_kodekloud-voting-app/](../../2_kodekloud-voting-app/)
- `helm` and `kubectl` installed

```bash
kubectl config current-context   # kind-home-k8-cluster
kubectl -n demo-voting-app get svc vote result
```

## 1. Helm install (ingress controller)

Platform-owned component. Kind-specific settings are in `kind-helm-values.yaml`.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --version 4.12.1 \
  -f kind-helm-values.yaml
```

Wait for the controller:

```bash
kubectl -n ingress-nginx wait --for=condition=Ready pod \
  -l app.kubernetes.io/component=controller --timeout=180s
kubectl -n ingress-nginx get pod -o wide
```

Controller pod should be on `home-k8-cluster-control-plane`.

Or run all steps via script:

```bash
chmod +x deploy-ingress.sh
./deploy-ingress.sh
```

## 2. Deploy app Ingress resource

Team-owned routing rules:

```bash
kubectl apply -f 01-voting-app-ingress.yaml
kubectl -n demo-voting-app get ingress voting-app
```

## 3. Validate

Browser:
- http://demo-vote.localhost/
- http://demo-vote.localhost/result

Terminal:

```bash
curl -H "Host: demo-vote.localhost" http://127.0.0.1/
curl -H "Host: demo-vote.localhost" http://127.0.0.1/result
```

Cast a vote on `/` and confirm counts update on `/result`.

## Next step

[../../4_observability-grafana-stack/](../../4_observability-grafana-stack/) — LGTM observability stack

## Cleanup

```bash
chmod +x uninstall-ingress.sh
./uninstall-ingress.sh
```

If Helm reports `ClusterRole "ingress-nginx" exists and cannot be imported`, run `./uninstall-ingress.sh` once, then `./deploy-ingress.sh` again.
