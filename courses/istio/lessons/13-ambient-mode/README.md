# Ambient mode: ztunnel and a waypoint instead of sidecars

## Concept

Sidecars work, but every Pod pays for an Envoy (memory, a restart to
inject or upgrade, a container in every spec). **Ambient mode** splits the
data plane into two layers:

- **ztunnel** ("zero-trust tunnel"): one small Rust proxy per **node**
  (a DaemonSet). The istio-cni agent redirects the traffic of enrolled
  Pods into it. ztunnel gives every workload its identity and mTLS,
  tunnels traffic between nodes over **HBONE** (HTTP CONNECT over mTLS, port
  15008), and enforces **L4** authorization (identities, namespaces, ports).
  It never parses HTTP.
- **waypoint**: an Envoy Deployment you add only where you need **L7**
  (HTTP routing, retries, fault injection, L7 authorization, HTTP metrics).
  It is a Gateway API `Gateway` of class `istio-waypoint`, usually one per
  namespace. Services or namespaces opt in with the label
  `istio.io/use-waypoint: <waypoint-name>`; traffic to them then goes
  client ztunnel -> waypoint -> server ztunnel.

Enrolling is one label, and no restarts:

    kubectl label namespace mall istio.io/dataplane-mode=ambient

Policies attach to what enforces them:

| Policy | Enforced by | Can use |
|---|---|---|
| AuthorizationPolicy with `selector` (or none) | the destination's ztunnel | principals, namespaces, ports (L4) |
| AuthorizationPolicy with `targetRefs` to a Service or the waypoint Gateway | the waypoint | everything, incl. methods, paths, headers (L7) |

A `selector` policy that uses L7 attributes cannot be enforced by ztunnel,
so ztunnel treats its rules as not matching: for an ALLOW policy that
means deny. Routing works the same way: an HTTPRoute (or VirtualService)
for a Service is applied by its waypoint, not by the client.

Sidecar and ambient workloads interoperate in one mesh (this cluster runs
both: the course's other lessons use sidecars).

## The situation

Namespace `mall` runs `web` and `bot` (curl clients, each with its own
ServiceAccount) and `api` (HTTP server on Service port 8000). It is not
in the mesh: no sidecars, no ambient, no policy.

## Your task

- Enrol namespace `mall` in ambient mode (no sidecars, no restarts needed).
- Deploy a waypoint named `waypoint` in `mall` and route traffic for the
  namespace's Services (or at least `api`) through it.
- Attach an AuthorizationPolicy to the `api` Service so that only
  `mall/web` may call it, and only with `GET`: `web` POST and anything from
  `bot` get 403.

## Useful commands

    kubectl get pods -n istio-system -l app=ztunnel
    istioctl ztunnel-config workloads | grep mall
    istioctl waypoint generate -n mall          # print the waypoint Gateway
    istioctl waypoint list -n mall
    kubectl -n mall get gateway,pods
    kubectl -n istio-system logs ds/ztunnel --tail=5     # one line per connection
    kubectl -n mall exec deploy/web -c curl -- curl -sI api:8000/get

When you think you're done: `kdrill verify`

## On a real cluster

Ambient is GA since Istio 1.24. Its CNI part must fit the cluster's CNI
(this lab sets `global.platform: k3s`). Start with ztunnel only (mTLS and L4
policy everywhere for little memory) and add waypoints for the namespaces
that need L7. Moving a namespace between sidecar and ambient means
removing `istio-injection` and restarting its Pods once.

## Read more

- https://istio.io/latest/docs/ambient/overview/
- https://istio.io/latest/docs/ambient/usage/add-workloads/
- https://istio.io/latest/docs/ambient/usage/waypoint/
- https://istio.io/latest/docs/ambient/usage/l4-policy/
- https://istio.io/latest/docs/ambient/usage/l7-features/
