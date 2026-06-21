# Kubernetes Networking Roadmap

This area should become the networking track for the Kubernetes part of the sandbox.

From a platform engineering perspective, the goal is not just exposing an app. The goal is to understand how traffic enters the cluster, how it is routed, how it is secured, how teams consume shared networking primitives, and how you troubleshoot failures.

## Start Here

The first concrete experiment in this track is [kubernetes/networking/ingress-nginx/README.md](kubernetes/networking/ingress-nginx/README.md).

It places `ingress-nginx` in front of the existing demo voting app running in kind so you can move from `port-forward` access to a shared HTTP entry point.

## Recommended Focus Order

1. Services and DNS fundamentals
2. Ingress with an ingress controller
3. Gateway API with `Gateway` and `HTTPRoute`
4. NetworkPolicy for east-west isolation
5. Service mesh and Istio mTLS
6. TLS automation and certificate lifecycle
7. Egress control and outbound dependencies
8. Observability for traffic and policy debugging

## Why Start With Ingress, Gateway, And HTTPRoute

These are the highest-leverage entry points for platform engineering because they define how application teams publish HTTP services safely and consistently.

### Ingress

Study `Ingress` first because it is still widely used and you will see it in many existing clusters.

What to learn:
- host and path based routing
- ingress class selection
- controller-specific annotations and their operational risk
- TLS termination
- default backends and error handling

Why it matters:
- many internal platforms still standardize on NGINX Ingress
- most migration work toward Gateway API starts from an Ingress estate
- it teaches the older contract that many teams still depend on

### Gateway API

Study Gateway API next because it is a better long-term model for shared platform ownership.

What to learn:
- `GatewayClass`, `Gateway`, `HTTPRoute`, and attachment model
- separation between infrastructure owner and application owner responsibilities
- listener concepts, namespaces, and route binding rules
- portable policy model versus controller-specific annotations

Why it matters:
- it is a cleaner API for multi-tenant platforms
- it supports safer delegation than classic Ingress
- it lines up better with managed Kubernetes and service mesh ecosystems

### HTTPRoute

Go deep on `HTTPRoute`, not just Gateway API at a high level.

What to learn:
- hostname and path matches
- header and query param matching
- weighted traffic splitting
- request redirects and rewrites
- cross-namespace route attachment controls

Why it matters:
- this is where app delivery behavior is actually expressed
- it maps directly to progressive delivery and safer rollout patterns
- it becomes the contract your application teams consume

## Other Critical Topics To Explore

If you are thinking like a platform engineer, these are the next important networking topics after ingress and Gateway API.

### 1. Services And Service Discovery

Do not skip the basics.

Focus on:
- `ClusterIP`, `NodePort`, and `LoadBalancer`
- kube-proxy behavior and the service VIP model
- CoreDNS and service discovery
- readiness versus traffic eligibility

Why this matters:
- most routing problems still collapse down to service selection, endpoints, or DNS
- you need these fundamentals before ingress or Gateway troubleshooting makes sense

### 2. NetworkPolicy

This is the minimum useful east-west security layer in Kubernetes.

Focus on:
- default deny patterns
- namespace isolation
- ingress versus egress policy behavior
- how policies depend on your CNI capabilities

Why this matters:
- platform teams need a sane tenant isolation story
- many clusters look secure until you test lateral movement

### 3. TLS And Certificate Management

Focus on:
- cert-manager basics
- terminating TLS at ingress or gateway
- internal versus public certificates
- certificate rotation failure modes

Why this matters:
- operational TLS ownership usually lands on the platform team
- most production ingress issues eventually involve certificates, trust chains, or renewal

### 4. Service Mesh And Istio mTLS

Focus on:
- sidecar injection model versus ambient direction of travel
- namespace scoped mTLS rollout
- `PeerAuthentication` and `DestinationRule`
- ingress gateway versus internal service-to-service encryption
- what breaks when non-mesh workloads talk to meshed workloads

Why this matters:
- mTLS is one of the clearest platform-owned controls for east-west security
- many enterprises use Istio or a similar mesh to enforce identity and encryption between workloads
- it teaches the operational tradeoff between security posture and application compatibility

### 5. CNI And Data Plane Behavior

Focus on:
- what CNI is installed in the cluster
- whether it uses iptables, IPVS, or eBPF data paths
- what features it enables for policy, observability, and performance

Why this matters:
- the CNI decides what networking and policy features really exist
- troubleshooting gets much easier when you understand the data plane under the APIs

### 6. Egress Control

Focus on:
- how pods reach external services
- DNS based egress dependencies
- proxy patterns, NAT, and allow-list enforcement
- controlling access to SaaS endpoints and package registries

Why this matters:
- outbound traffic is often less governed than inbound traffic
- real enterprise controls usually require an explicit egress model

### 7. Traffic Observability

Focus on:
- access logs from ingress controllers or gateways
- request metrics and golden signals
- tracing across north-south and east-west hops
- debugging with `kubectl describe`, events, endpoints, and controller logs

Why this matters:
- routing ownership without visibility turns into blind operations
- platform teams need shared diagnostics that app teams can also use

## Suggested Experiment Sequence For This Repo

Keep this track incremental. One folder per experiment is the cleanest model.

Suggested sequence:

1. `network/services-basics/`
2. `network/ingress-nginx/`
3. `network/gateway-api-basic/`
4. `network/gateway-api-advanced-routing/`
5. `network/network-policy/`
6. `network/istio-mtls/`
7. `network/cert-manager-tls/`
8. `network/egress-control/`

For each experiment, include:
- goal and architecture sketch
- prerequisites
- install commands
- sample app or echo service
- validation commands
- cleanup commands
- common failure modes

## Practical First Milestone

If you want the best next step, build these two experiments first:

1. NGINX Ingress with one demo app exposed on path and host rules
2. Gateway API with one `Gateway` and two `HTTPRoute` examples for path routing and weighted traffic split

Then add Istio mTLS on the same demo namespace to understand how north-south and east-west controls complement each other.

## Validation Commands You Will Use Repeatedly

```bash
kubectl get svc,ep -A
kubectl get ingress -A
kubectl get gateway,httproute -A
kubectl get peerauthentication,destinationrule -A
kubectl describe ingress <name>
kubectl describe gateway <name>
kubectl describe httproute <name>
kubectl get events -A --sort-by=.lastTimestamp
kubectl logs -n <namespace> <controller-pod-name>
curl -H "Host: demo.local" http://127.0.0.1/
```

## Platform Engineering Lens

As you build this area, evaluate each topic with these questions:

- what is the contract for app teams
- what is centralized versus delegated
- how is policy enforced
- how is TLS handled
- how is troubleshooting done at 2 AM
- what is portable across clusters and vendors
- what breaks during upgrades or controller swaps

If you answer those well, you are not just learning Kubernetes networking. You are designing a usable platform surface.
