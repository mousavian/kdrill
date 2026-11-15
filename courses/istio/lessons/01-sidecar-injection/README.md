# Sidecar injection: putting workloads into the mesh

## Concept

A **service mesh** moves networking concerns (encryption, identity,
retries, routing, telemetry) out of application code into a proxy that
sits next to every workload. Istio's proxy is **Envoy**. Istio has two
ways to run it (two "data planes"):

- **Sidecar mode** (this lesson and most of the course): an Envoy container
  inside every Pod. Traffic in and out of the Pod is redirected through it.
- **Ambient mode** (lesson 13): no sidecars; a per-node proxy (ztunnel) for
  L4 and optional per-namespace Envoy "waypoints" for L7.

**istiod** is the control plane. It watches Services, Pods and Istio's own
resources, computes Envoy configuration for every proxy, and streams it to
them over **xDS** (gRPC). It also acts as a certificate authority: each
proxy gets a short-lived certificate for its workload's identity,
`spiffe://cluster.local/ns/<namespace>/sa/<serviceaccount>`.

**Injection.** You never write the sidecar into your manifests. istiod
runs a mutating admission webhook; when a Pod is created in a namespace
labelled `istio-injection=enabled`, the webhook adds:

- `istio-proxy`: `pilot-agent` (bootstraps Envoy, fetches certificates)
  plus Envoy. On recent Kubernetes it is a **native sidecar**: listed under
  `initContainers` with `restartPolicy: Always`, so it starts before and
  stops after your containers.
- an init container that sets up traffic redirection. This cluster runs the
  Istio CNI agent, which does the iptables work on the node, so Pods only
  get a small unprivileged `istio-validation` check instead of the
  privileged `istio-init`.

Because the webhook only sees **Pod creation**, labelling a namespace does
nothing to running Pods: restart the workloads. A single Pod opts out with
the label `sidecar.istio.io/inject: "false"` in its Pod template (labels and
annotations on the Deployment object itself are ignored).

**Auto mTLS.** When both sides have a sidecar, the client proxy upgrades the
connection to mutual TLS automatically and the server proxy adds the caller's
identity in the `X-Forwarded-Client-Cert` request header. By default servers
are **PERMISSIVE**: they also accept plaintext from callers without a sidecar.
Lesson 09 makes that STRICT.

## The situation

Namespace `shop` runs four Deployments, none of them in the mesh yet:
`web` and `api` (small HTTP echo servers, Service port 8000), `client` (a
curl Pod used to send requests), and `batch` (a batch runner the security
team wants outside the mesh for now).

## Your task

- Enable sidecar injection for namespace `shop` and get `web`, `api` and
  `client` running with a ready `istio-proxy` sidecar.
- Keep `batch` out of the mesh with `sidecar.istio.io/inject: "false"` in
  its Pod template, running and Ready.
- Show that `client -> api` goes over mTLS: `api` must see the
  identity `spiffe://cluster.local/ns/shop/sa/client`.
- `batch` (no sidecar) must still reach `web` in plaintext.

`kdrill verify` sends real requests from the `client` and `batch` Pods.

## Useful commands

    kubectl -n shop get pods                         # READY 2/2 = app + sidecar
    kubectl -n shop get pod -l app=web -o jsonpath='{.items[0].spec.initContainers[*].name}'
    kubectl -n shop exec deploy/client -c curl -- curl -s api:8000/headers
    istioctl proxy-status                            # which proxies istiod knows, SYNCED?
    istioctl analyze -n shop                         # common misconfigurations

`istioctl` is the pinned 1.31.4 that the course put at `~/.kdrill/bin/istioctl`
(`export PATH="$HOME/.kdrill/bin:$PATH"`). It uses your current kubectl
context, so make sure that is `k3d-kdrill`.

When you think you're done: `kdrill verify`

## On a real cluster

Teams usually pin a control-plane **revision** instead
(`istio.io/rev=<revision>` on the namespace) so that upgrades can move
namespaces one at a time. The sidecar here is limited to 256 MiB and one
worker thread; production sidecars are sized to their traffic.

## Read more

- https://istio.io/latest/docs/ops/deployment/architecture/
- https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/
- https://istio.io/latest/docs/concepts/security/#mutual-tls-authentication
- https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/
