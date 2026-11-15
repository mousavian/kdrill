# kdrill status

Last updated: 2026-11-15

## Courses

| Course | Lessons | Extra components | Notes |
|---|---|---|---|
| k8s-scheduling | 6 | – | start here |
| gpu-scheduling | 12 | kueue, gpu-binpack-scheduler, kwok-job-runtime | all simulated on fake nodes |
| karpenter | 12 | karpenter-kwok (built from source, needs Go + helm) | first `course start` builds an image (~90 s) |
| kyverno | 13 | kyverno (helm) | ~1 GB extra RAM while installed; lessons 08 and 12 need internet |
| envoy | 38 | envoy-gateway v1.9.3 (helm) | real containers; 01–21 plain Envoy, 22–34 Envoy Gateway, 35 inference bridge, 36 capstone, 37–38 extras (cross-namespace routes, basic auth); ~130 MB of images pulled on first start |
| inference | 26 | inference-models (SmolLM2-135M GGUF + images), metrics-server v0.9.1, keda v2.21.0, envoy-gateway v1.9.3 (shared with envoy), inference-gateway (CRDs + Lua) | real-compute for Parts A-C and the capstone (llama.cpp on CPU; llm-d-inference-sim; llm-d router endpoint picker), sim for Part D (fake GPU nodes); first `course start` downloads 105 MB + about 600 MB of images |
| istio | 14 | istio (istioctl 1.31.4 + Gateway API v1.6.3 CRDs) | real-light: real containers and traffic on the k3d node; about 120 MB for istiod + CNI agent + ztunnel, about 30 MB per sidecar |

Not built yet, each with a ready-to-use build brief (`courses/<name>/BUILD.md`):
training, fine-tuning, kubeflow (the kubeflow brief produces
several small courses). To build one, open a new session in this folder and say:
"Build the course described in courses/<name>/BUILD.md". Suggested order:
training, fine-tuning, kubeflow.

## Decisions made without you — review these

1. **Kyverno has 13 lessons** (you asked for 10–20; the brief said 10–12). Lesson 08 (verify-images) is the easiest to drop.
2. **Kyverno teaches the classic `ClusterPolicy`** in 11 of 13 lessons, although Kyverno v1.19 marks it deprecated; lesson 11 teaches the CEL replacement (`ValidatingPolicy`).
3. **Karpenter is patched** (one line, `base/components/karpenter-kwok/kwok-node-capacity.patch`): upstream's KWOK provider reports a fake node's capacity as the pod requests that triggered it, which breaks NodePool limits. The patch makes nodes report the instance type's full capacity.
4. **Karpenter's instance catalogue is hand-written** (`base/components/karpenter-kwok/catalog.txt`): 36 types, prices approximate.
5. **Bin-packing uses a second scheduler** (`schedulerName: gpu-binpack`) rather than changing the default scheduler's profile.
6. **Kueue's visibility API is removed at install**, because it makes `kubectl api-resources` fail while the controller restarts and the engine's cleanup depends on that command.
7. **Lesson cleanup in the kyverno and karpenter courses deletes every policy / NodePool in the cluster**, not only the lesson's.
8. **Fake Job pods**: KWOK normally completes Job pods instantly; the `kwok-job-runtime` component makes them honour a delay annotation so training Jobs appear to run.
9. **Envoy is one course of 38 lessons** (36, plus 37 cross-namespace routes and 38 basic auth, which came from an earlier 14-lesson draft) rather than two courses. Left out: global (Redis) rate limiting, GRPCRoute, hands-on ext_authz, a gRPC xDS control plane in Part A.
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

20. **Inference: the model server is a real tiny model, the simulator, or fake pods, per lesson.** Part A (01-07) runs llama.cpp (`ghcr.io/ggml-org/llama.cpp:server-b12375`, pinned by digest) with SmolLM2-135M-Instruct Q4_K_M (105 MB, Apache-2.0, from `bartowski/SmolLM2-135M-Instruct-GGUF` at a pinned revision, sha256 verified): about 270 MB RSS, 57 tokens/s, loads in 1.5-3 s. Parts B-C and the capstone use `llm-d-inference-sim` v1.2.0 (vLLM-compatible API and metrics, 45 MB image, runtime knobs through `/admin/config`: latencies, fake saturation, failures), always in echo mode so that answer length and duration are predictable. Part D (20-25) is KWOK fake GPU nodes (sim kind), reusing `gpu_node` and the other helpers from the gpu-scheduling course by sourcing its `lib.sh`.
21. **The model file lives in two places on the node**: a hostPath (`/var/lib/kdrill/models`, lessons 01 and 04-07) and a `FROM scratch` OCI image `kdrill.local/smollm2-135m:q4km` imported into containerd (lesson 02, Kubernetes image volumes, on by default in k3s v1.35). The downloaded GGUF is cached in `$KDRILL_STATE_DIR/models` and kept by `course stop`.
22. **Model-load time is artificial in lesson 03 and 10** (`--startup-duration` of the simulator: 15 s and 20 s) because the real 135M model loads in 1.5-3 s; the READMEs say so. Lesson 03 also notes that the simulator serves requests while `/health/ready` is 503.
23. **The Gateway API Inference Extension is wired in by hand.** Envoy Gateway v1.9.3 answers an HTTPRoute whose backendRef is an `InferencePool` with `ResolvedRefs=False / InvalidKind` (that support needs Envoy AI Gateway). Lessons 15-17 therefore use a normal Service backend plus an `EnvoyExtensionPolicy` (ext_proc to the endpoint picker, `FullDuplexStreamed` bodies) and a `BackendTrafficPolicy` `endpointOverride` on the header `x-gateway-destination-endpoint`: what an inference-aware gateway generates. The `InferencePool` object is still created (the picker reads it). Envoy lesson 35 prepared the second half.
24. **The endpoint picker moved projects.** The Gateway API Inference Extension repository (v1.6.2) now ships only the `InferencePool` API and a round-robin conformance picker; the real picker, `InferenceObjective` (API group `llm-d.ai`, `v1`) and `InferenceModelRewrite` live in `llm-d/llm-d-router` v1.0.0. The course uses that picker (`ghcr.io/llm-d/llm-d-router-endpoint-picker:v1.0.0`, pinned by digest, plain h2c with `--secure-serving=false`, metrics refresh 200 ms) and its CRDs. `InferenceModelRewrite` and the picker's flow-control feature gate are mentioned, not taught.
25. **Body-based routing is an inline Lua filter** (`EnvoyExtensionPolicy`, lesson 13): Envoy Gateway ships Lua disabled, so the `inference-gateway` component switches on `extensionApis.enableLua` in the controller's ConfigMap and restarts the controller (reverted on stop). The Gateway needs a catch-all rule because Envoy Gateway enables the Lua filter per matched route.
26. **No Prometheus**: KEDA's `metrics-api` scaler reads JSON from a 70-line stdlib Python adapter (`courses/inference/assets/aggregator.py`, run on `python:3.13-alpine`) that sums every pod's `/metrics`. Autoscaling lessons scale on in-flight requests (running + waiting) with the target equal to the slots per replica; the READMEs explain why `running` and `waiting` alone fail. metrics-server is installed as a component for lesson 08 (CPU HPA).
27. **Kueue was dropped from the course** (the brief listed it): its mutating Deployment webhook (failurePolicy Fail) made `kubectl apply` of a Deployment fail with "no endpoints" whenever the Kueue pod restarted under load. Lesson 22 covers priority and preemption and points to gpu-scheduling lessons 05-09 for quotas, borrowing and reclaim.
28. **Not built from the brief**: the Karpenter-based scale-to-zero lesson (node provisioning); lesson 10 covers the cold-start costs without node provisioning. The brief's lessons 21 (priority + Kueue) and 18 (rate limit + canary) became lessons 22, and 18 and 19.
29. **Lesson cleanup in inference lesson 22 deletes every PriorityClass that is not `system-*`.**
30. **Several verify scripts act on the cluster**: 09 and 18 scale their load Deployments, 11/12/23/26 run `rollout restart` or set env vars to start a rollout, 24 deletes and recreates a fake node, 15/17 change simulator metrics through the admin API and restore them. Each README says so and gives the duration (up to 2-3 minutes for 09 and the capstone).

## Installed on this machine

- Homebrew: `k3d`, `helm`
- Docker: k3d cluster `kdrill`; image `kdrill.local/karpenter-kwok:v1.15.1-kdrill.1` (42 MB)
- `~/.kdrill/` (state, kubeconfig), `~/.cache/kdrill/` (Karpenter source, 21 MB)
- istio course: `~/.kdrill/bin/istioctl` (1.31.4, downloaded on `course start`)
- inference course: `~/.kdrill/models/SmolLM2-135M-Instruct-Q4_K_M.gguf` (105 MB, kept by `course stop`); in the k3d node `/var/lib/kdrill/models` (105 MB), the image `kdrill.local/smollm2-135m:q4km` (105 MB; also in the host Docker, built on `course start`), and the pulled images llama.cpp server (292 MB unpacked), llm-d-inference-sim (45 MB), llm-d router endpoint picker, python:3.13-alpine, curl (about 600 MB in all, removed with the cluster; the model image and file are removed by `course stop`)

## Memory

The k3s node grows as courses install CRDs and does not shrink on `course stop`.
After working through several courses, run `kdrill cluster down && kdrill cluster up`
to get the memory back. Keep one heavy course started at a time.

inference, measured on the test cluster (working set, `kubectl top`): keda-operator 35 Mi, keda-metrics-apiserver 35-70 Mi, metrics-server 15-30 Mi,
envoy-gateway 40-75 Mi, one gateway's Envoy 64 Mi, endpoint picker 35 Mi, a simulator pod 17-45 Mi, the metrics aggregator 20 Mi, a real llama.cpp server
270-300 Mi (`-c 4096`, 4 slots). The k3s node container itself was 1.4-1.9 GiB with all five components installed (the CRDs of Gateway API,
Envoy Gateway, KEDA and the inference extension grow the API server); the largest value sampled over a whole 26-lesson run was 1.73 GiB, while the main
`kdrill` cluster was using 0.9-1.1 GiB next to it. Only one real model replica runs at a time.

istio, measured on the test cluster (working set): istiod 62 MiB, istio-cni 50 MiB,
ztunnel 5 MiB; each sidecar, gateway or waypoint 27-30 MiB. The biggest lesson
(14: 6 meshed Pods plus a gateway) adds about 180 MiB; the whole k3s node was
1.7 GiB at that point.

## Known gaps

- Only spot-checked by the orchestrating session: k8s-scheduling 05/06, gpu-scheduling 07/10, karpenter 01, kyverno 01, envoy 01/25, istio 05/13/14, inference 01/09/13/15/16/17/20/22/24/26 (inference on a fresh `kdrill-dev` cluster, not on the main cluster, which was in use). Every lesson was run end to end by the agent that wrote it, on a separate test cluster.
- istio: every lesson was run end to end through `bin/kdrill` (start, verify fails on the untouched state, apply the solution, verify passes, cleanup by starting the next lesson) by the agent that wrote it, on a k3d cluster (k3d v5.9.0, k3s v1.35.5) inside a Linux container, not on the Mac. That host needed extra k3d flags the engine does not pass (containerd proxy and CA, containerd `restrict_oom_score_adj`, `--kubelet-arg=fail-cgroupv1=false`, kube-proxy `conntrack-max-per-core=0`), so `kdrill cluster up` there ran against a cluster created by hand with the engine's own flags plus those.
- istio: Istio 1.31 supports Kubernetes 1.32-1.37 (1.27-1.31 are "tested, not supported" upstream); `istioctl x precheck` passed on k3s 1.35. An older k3d whose default k3s is 1.31 (k3d 5.8.x) was not tried.
- istio: `hack/lesson.sh setup` always taints the real node (it was written for sim lessons), so it cannot run real-light lessons; use `kdrill start` for them.
- istio: on an untouched lesson, verify can take 10-20 s (requests that time out, a short wait for istiod to push new config).
- inference: every lesson ran end to end through `bin/kdrill` on a dev cluster (`kdrill-dev`) next to a busy main cluster; the evidence is in the agent report, not in the repo. Several lessons act on the cluster during verify (see decision 30) and are slow: 03 (39 s), 11 (35-45 s), 14 (30-50 s), 18 (45 s on the untouched state), 24 (up to 90 s), 26 (about 3 minutes).
- inference: the endpoint picker, `InferenceObjective` and the Lua body router are shipped by other projects and move fast (the picker moved from the inference-extension repository to llm-d-router while this course was written); versions are pinned in `base/components/inference-gateway`, `courses/inference/lib.sh` and the lessons.
- inference: Envoy Gateway needs about 15 s to warm a cluster that has a new `endpointOverride`, so lessons 15-17 and 26 wait for it in verify (`gw_wait_config`); a learner who verifies immediately after applying the policy can see a failure that passes a few seconds later.
- inference: with the endpoint picker and three or four requests at a time, about one request in a hundred is sent to a replica the picker's scorers should have ruled out (seen in lesson 16 as a 404 from a replica without the adapter). The cause was not found (the picker's choice or Envoy's fallback load balancer). Lesson 16's verify therefore asks for 26 of 30, not 30 of 30; lessons 15, 17 and 26 use the same wiring with wide margins and passed every run, but a rare failed verify there is possible.
- inference: on a fresh cluster the first `course start` took about 10 minutes (image pulls); later starts take about 2 minutes.
- inference: real batching gains cannot be shown on two CPU threads (lesson 07 says so); on a GPU they are large.
- inference: the Docker Desktop VM (3.8 GB) was shared with a running `kdrill` cluster during the build; the course was not tried on a machine with the main cluster stopped, and `course start` pulls about 600 MB of images the first time.
- inference: Kueue is installed by gpu-scheduling only; the inference course no longer installs it (decision 27).
- `kdrill course stop` does not clean up an active lesson first.
- envoy 37 and 38 were ported from an earlier draft onto this course's helpers and checked only with `bash -n` and a YAML parse; they have not been run end to end on a cluster.
- Lesson cleanup takes 20–30 s (namespace deletion), so `reset` is slow.
- Envoy lessons 15, 28, 32, 33, 35 take 10–18 s to verify (Envoy cluster warm-up, log flush, token refill); each README says so.
- Shared traffic/TLS helpers live in `courses/envoy/lib.sh`; later real-traffic courses should promote them to `base/lib/common.sh`.
- `kdrill next` moves on even if the current lesson isn't verified.
