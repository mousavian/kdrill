# kdrill status

Last updated: 2026-11-15

## Courses

| Course | Lessons | Extra components | Notes |
|---|---|---|---|
| k8s-scheduling | 6 | – | start here |
| gpu-scheduling | 12 | kueue, gpu-binpack-scheduler, kwok-job-runtime | all simulated on fake nodes |
| karpenter | 12 | karpenter-kwok (built from source, needs Go + helm) | first `course start` builds an image (~90 s) |
| kyverno | 13 | kyverno (helm) | ~1 GB extra RAM while installed; lessons 08 and 12 need internet |
| envoy | 36 | envoy-gateway v1.9.3 (helm) | real containers; 01–21 plain Envoy, 22–34 Envoy Gateway, 35 inference bridge, 36 capstone; ~130 MB of images pulled on first start |
| istio | 14 | istio (istioctl 1.31.4 + Gateway API v1.6.3 CRDs) | real-light: real containers and traffic on the k3d node; about 120 MB for istiod + CNI agent + ztunnel, about 30 MB per sidecar |

Not built yet, each with a ready-to-use build brief (`courses/<name>/BUILD.md`):
inference, training, fine-tuning, kubeflow (the kubeflow brief produces
several small courses). To build one, open a new session in this folder and say:
"Build the course described in courses/<name>/BUILD.md". Suggested order:
training, inference, fine-tuning, kubeflow.

## Decisions made without you — review these

1. **Kyverno has 13 lessons** (you asked for 10–20; the brief said 10–12). Lesson 08 (verify-images) is the easiest to drop.
2. **Kyverno teaches the classic `ClusterPolicy`** in 11 of 13 lessons, although Kyverno v1.19 marks it deprecated; lesson 11 teaches the CEL replacement (`ValidatingPolicy`).
3. **Karpenter is patched** (one line, `base/components/karpenter-kwok/kwok-node-capacity.patch`): upstream's KWOK provider reports a fake node's capacity as the pod requests that triggered it, which breaks NodePool limits. The patch makes nodes report the instance type's full capacity.
4. **Karpenter's instance catalogue is hand-written** (`base/components/karpenter-kwok/catalog.txt`): 36 types, prices approximate.
5. **Bin-packing uses a second scheduler** (`schedulerName: gpu-binpack`) rather than changing the default scheduler's profile.
6. **Kueue's visibility API is removed at install**, because it makes `kubectl api-resources` fail while the controller restarts and the engine's cleanup depends on that command.
7. **Lesson cleanup in the kyverno and karpenter courses deletes every policy / NodePool in the cluster**, not only the lesson's.
8. **Fake Job pods**: KWOK normally completes Job pods instantly; the `kwok-job-runtime` component makes them honour a delay annotation so training Jobs appear to run.
9. **Envoy is one course of 36 lessons** rather than two courses. Left out: global (Redis) rate limiting, GRPCRoute, hands-on ext_authz, a gRPC xDS control plane in Part A.
10. **Envoy lesson 35 (inference bridge) is a light stand-in**: a real InferencePool with an endpoint picker was judged too heavy, so the lesson uses Envoy Gateway's endpoint override (the mechanism a picker drives) and `verify` plays the picker.
11. **Envoy Gateway runs each Gateway's proxy in the lesson namespace** with a ClusterIP Service (no load balancer in the lab); traffic is sent from an in-cluster client pod.
12. **Remaining courses are not built**; each has a brief at `courses/<name>/BUILD.md` for a fresh session.
13. **Istio is installed with the pinned istioctl, not helm**: Istio 1.31 is not on the classic helm repository (it stops at 1.30.8 and a 1.31 rc), and the lessons need istioctl anyway. The component downloads istioctl 1.31.4 (checksum-verified) into `~/.kdrill/bin` and runs `istioctl install -f base/components/istio/istio-operator.yaml`.
14. **One install serves both data planes**: profile `ambient` (istiod + istio-cni + ztunnel). Lessons 01-12 and 14 use sidecars (`istio-injection=enabled`), lesson 13 uses ambient with a waypoint. Because istio-cni is present, sidecar Pods get the small `istio-validation` init container instead of the privileged `istio-init`. IPv6 is switched off for ztunnel and the CNI agent (the cluster is IPv4-only, and ambient failed without it on a host with no IPv6).
15. **Ingress uses the Gateway API, in-mesh routing uses VirtualService/DestinationRule.** Gateway API is Istio's recommended ingress API and waypoints need it; retries, fault injection, subsets and outlier detection are taught with the classic API most meshes run. The component installs the Gateway API v1.6.3 standard CRDs only if none are present, and removes them on `course stop` only if it added them.
16. **Gateways get a ClusterIP Service** (annotation `networking.istio.io/service-type: ClusterIP`) because the engine's cluster has no load balancer. verify calls them from a curl Pod without sidecar in namespace `outside`; all traffic checks run `curl` inside lesson Pods with `kubectl exec`.
17. **Not taught**: egress control (ServiceEntry, REGISTRY_ONLY) and TLS origination/termination, to keep 14 lessons and avoid lessons that need internet from Pods. Lesson 03's README points at HTTPS listeners.
18. **Lesson cleanup in the istio course deletes every Istio policy and routing object in `istio-system`** (mesh-wide PeerAuthentication, AuthorizationPolicy, Telemetry, ...), so nothing leaks into the next lesson.
19. **Mesh sizing**: one Envoy worker thread per sidecar, sidecars request 40 Mi and are limited to 256 Mi, istiod requests 128 Mi. Istio trims Envoy's per-cluster stats by default; lessons 06 and 08 add a `proxyStatsMatcher` annotation to their client so retry/outlier/overflow counters can be read.

## Installed on this machine

- Homebrew: `k3d`, `helm`
- Docker: k3d cluster `kdrill`; image `kdrill.local/karpenter-kwok:v1.15.1-kdrill.1` (42 MB)
- `~/.kdrill/` (state, kubeconfig), `~/.cache/kdrill/` (Karpenter source, 21 MB)
- istio course: `~/.kdrill/bin/istioctl` (1.31.4, downloaded on `course start`)

## Memory

The k3s node grows as courses install CRDs and does not shrink on `course stop`.
After working through several courses, run `kdrill cluster down && kdrill cluster up`
to get the memory back. Keep one heavy course started at a time.

istio, measured on the test cluster (working set): istiod 62 MiB, istio-cni 50 MiB,
ztunnel 5 MiB; each sidecar, gateway or waypoint 27-30 MiB. The biggest lesson
(14: 6 meshed Pods plus a gateway) adds about 180 MiB; the whole k3s node was
1.7 GiB at that point.

## Known gaps

- Only spot-checked by the orchestrating session: k8s-scheduling 05/06, gpu-scheduling 07/10, karpenter 01, kyverno 01, envoy 01/25, istio 05/13/14. Every lesson was run end to end by the agent that wrote it, on a separate test cluster.
- istio: every lesson was run end to end through `bin/kdrill` (start, verify fails on the untouched state, apply the solution, verify passes, cleanup by starting the next lesson) by the agent that wrote it, on a k3d cluster (k3d v5.9.0, k3s v1.35.5) inside a Linux container, not on the Mac. That host needed extra k3d flags the engine does not pass (containerd proxy and CA, containerd `restrict_oom_score_adj`, `--kubelet-arg=fail-cgroupv1=false`, kube-proxy `conntrack-max-per-core=0`), so `kdrill cluster up` there ran against a cluster created by hand with the engine's own flags plus those.
- istio: Istio 1.31 supports Kubernetes 1.32-1.37 (1.27-1.31 are "tested, not supported" upstream); `istioctl x precheck` passed on k3s 1.35. An older k3d whose default k3s is 1.31 (k3d 5.8.x) was not tried.
- istio: `hack/lesson.sh setup` always taints the real node (it was written for sim lessons), so it cannot run real-light lessons; use `kdrill start` for them.
- istio: on an untouched lesson, verify can take 10-20 s (requests that time out, a short wait for istiod to push new config).
- `kdrill course stop` does not clean up an active lesson first.
- Lesson cleanup takes 20–30 s (namespace deletion), so `reset` is slow.
- Envoy lessons 15, 28, 32, 33, 35 take 10–18 s to verify (Envoy cluster warm-up, log flush, token refill); each README says so.
- Shared traffic/TLS helpers live in `courses/envoy/lib.sh`; later real-traffic courses should promote them to `base/lib/common.sh`.
- `kdrill next` moves on even if the current lesson isn't verified.
