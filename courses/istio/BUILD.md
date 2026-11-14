# BUILD brief — `istio` course

You are building one kdrill course in a fresh session. Everything you need is in
this repo. Read, in this order, before writing anything:

1. `hack/COURSE_AUTHORING.md` — layout, limits, quality bar, test cycle, and the
   section "Building from a BUILD.md brief" (your permissions and hand-off).
2. `DESIGN.md`, `README.md`, `STATUS.md`, `base/lib/common.sh`, `base/lib/lesson.mk`.
3. `courses/envoy/` in full (course.yaml, lib.sh, two or three lessons, its
   component under `base/components/`). It is the closest existing course: real
   containers, real traffic, in-cluster client pods. Reuse its traffic helpers
   (source its `lib.sh` or promote the shared ones to `base/lib/common.sh`).
4. `courses/kyverno/` for admission-style checks and a helm-installed component.

## Goal

A learner who finishes can run Istio on a cluster, explain what the data plane
is doing in both sidecar and ambient mode, shift and shape traffic, lock
workloads down with mTLS and authorization policy, and debug a broken mesh with
`istioctl`. Lessons are hands-on: every lesson starts broken or incomplete and
`verify` checks real traffic behaviour.

- Directory: `courses/istio`, `kind: real-light`, `requires: [envoy]` (informational).
- No lesson cap. Use as many lessons as the topic needs; one concept each.

## Machine constraints that shape this course

8 GB Mac, Docker VM 4 GB, one k3s node. Budget for Istio plus a lesson's
workloads: about 1.5 GB. That means:

- Install with **helm** (already on the machine), pinned chart versions: `base`,
  `istiod`, and for ambient `cni` + `ztunnel`. No ingress gateway chart by default;
  gateways are created per lesson through the Kubernetes Gateway API.
- On k3s the CNI chart needs the k3s platform setting (believed to be
  `--set global.platform=k3s` on the `cni`, and possibly `istiod`/`ztunnel`,
  charts — **verify against the Istio docs for the version you pin**). Without it
  the CNI plugin writes to the wrong directories and ambient silently does nothing.
- Shrink requests: istiod (~100m / 256Mi or less), sidecar proxy via
  `global.proxy.resources` (around 10m / 40Mi request), one replica of
  everything, autoscaling off, no Prometheus/Grafana/Kiali/Jaeger addons.
- Lesson workloads: two to four tiny pods (a small multi-arch HTTP echo server
  that returns its version/hostname and request headers, and a curl client).
  Use the same images as the envoy course.
- Gateway API CRDs: check how the envoy course's component installs them. Two
  components must not fight over the same CRDs. If needed, split them into a
  shared `gateway-api-crds` component that both courses list.
- Measure memory with sidecar-only and with ambient added. If both together do
  not fit, make ambient a separate component that only the ambient lessons need,
  or split into two courses (`istio` and `istio-ambient`). Record the decision.

## Component

`base/components/istio/{install.sh,uninstall.sh}` — idempotent, pinned.
`istioctl` (needed by lessons for `proxy-config`, `analyze`, `x describe`) is
downloaded to `$KDRILL_STATE_DIR/bin`, pinned and checksum-verified, never
installed system-wide; tell the learner how to put it on PATH. Uninstall must
remove CRDs, webhooks (mutating and validating), cluster roles, the CNI config
on the node, and `istio-system`, and a later install must work. Namespaces
labelled for injection must not block pod creation after uninstall (a leftover
mutating webhook with no backend is the classic hang — test it).

## Proposed lesson outline (a starting point — reorder, split, add)

Part A — sidecar data plane
1. Join the mesh: namespace injection label, restart, see the second container.
2. What the sidecar does: iptables redirect, inbound/outbound listeners;
   read them with `istioctl proxy-config listeners|routes|clusters|endpoints`.
3. Opting workloads in and out: pod-level injection labels, revision labels.
4. Sidecar resource and startup ordering problems (app starts before proxy;
   native sidecars / `holdApplicationUntilProxyStarts`).

Part B — traffic management
5. DestinationRule subsets + VirtualService: pin all traffic to v1.
6. Weighted canary 90/10, then promote.
7. Header- and path-based routing (route testers to v2).
8. Timeouts and retries (backend that fails or is slow on demand).
9. Fault injection: delay and abort, and how it interacts with timeouts.
10. Circuit breaking and outlier detection (connection pool limits, ejection).
11. Traffic mirroring.
12. Ingress with the Gateway API (`Gateway` + `HTTPRoute`, Istio's gateway class),
    reached with port-forward or an in-cluster client; TLS termination.
13. Egress control: `outboundTrafficPolicy: REGISTRY_ONLY` and `ServiceEntry`.
    There is no reliable internet in a lesson: model "external" as a service in a
    namespace outside the mesh.
14. Locality / load-balancing policy (optional; only if it can be verified).

Part C — security
15. mTLS modes: PERMISSIVE vs STRICT with `PeerAuthentication`; a plaintext client
    from a non-mesh namespace must be rejected. Port-level exceptions.
16. Workload identity: SPIFFE IDs from service accounts; see the client cert
    (`X-Forwarded-Client-Cert` echoed by the backend, `istioctl proxy-config secret`).
17. `AuthorizationPolicy`: default deny, then allow by namespace / service account.
18. Authorization on method, path and headers; deny vs allow precedence.
19. End-user auth: `RequestAuthentication` + JWT claims. Generate a key pair and
    tokens in setup.sh (inline JWKS in the policy; no external issuer).

Part D — observability and debugging
20. Access logs with the `Telemetry` API; read response flags (UH, UF, NR, URX).
21. Proxy metrics without Prometheus: scrape `:15020/stats/prometheus` from a
    client pod; `istio_requests_total` labels. Only add a tiny Prometheus if it
    fits the budget, and then as an optional lesson.
22. Debug a broken mesh: three or four planted faults (port name/protocol
    mismatch, DestinationRule/PeerAuthentication TLS conflict producing 503,
    VirtualService host typo, missing subset). `istioctl analyze`, `x describe`.
23. Scoping configuration with the `Sidecar` resource (and why it matters at scale).

Part E — ambient mode
24. Move a namespace to ambient (`istio.io/dataplane-mode=ambient`): no sidecars,
    no restarts, ztunnel carries mTLS (HBONE). Prove it: identity and encryption
    without a second container.
25. L4 authorization in ambient (what ztunnel can and cannot enforce).
26. Waypoint proxies: add L7 routing/authorization for one service; what breaks
    when an L7 policy has no waypoint.
27. Sidecar vs ambient: migrate one workload, compare footprint.

Capstone
28. A small three-service app with several requirements at once (canary, strict
    mTLS, least-privilege authz, one planted fault). Verify checks all of them.

## How verify should work

- Send real requests from a client pod and assert on outcomes: status codes,
  which version answered, headers echoed back. For weights, send enough requests
  (100–200) and accept a tolerance band; never assert an exact split.
- Assert mechanism where it is the point (the object exists with the right
  mode; the pod has or lacks a sidecar; ztunnel reports the workload).
- Guard against cheats: scaling v2 to zero instead of routing, deleting the
  policy instead of fixing it, moving the client into the mesh instead of
  allowing it, setting PERMISSIVE when STRICT is required.
- Config propagation takes a second or two: poll briefly, never sleep blindly.

## Known traps

- Port naming / `appProtocol` decides whether Istio treats traffic as HTTP.
- Pods created before the injection label need a restart; setup.sh must do it.
- STRICT mTLS breaks kubelet probes only for non-rewritten probes; check your
  echo server's probes work in both modes.
- VirtualService for mesh-internal traffic binds to the `mesh` gateway by
  default; mixing it with a Gateway binding is a classic lesson and a classic bug.
- Namespace deletion can stall on Istio finalizers or webhooks; cleanup must not hang.
- The sim taint is off for `real-light`, but KWOK fake nodes may exist from
  other courses: workloads and the CNI DaemonSet must never target fake nodes
  (node affinity on `kwok.x-k8s.io/node` / `type!=kwok`; see how the other
  components do it).

## Check upstream before relying on it

Current stable Istio version and its supported Kubernetes versions (cluster is
k3s v1.35.x); helm chart names and values; the k3s platform setting; Gateway API
version Istio expects; whether ambient waypoint and `Telemetry` fields changed;
`istioctl` download URL and checksums for darwin-arm64.

## Done means

Every lesson passes the full test cycle in `hack/COURSE_AUTHORING.md`; course
stop/start is clean; footprint is measured and written in STATUS.md; this file is
deleted; committed to `main`.
