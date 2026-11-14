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

Not built yet, each with a ready-to-use build brief (`courses/<name>/BUILD.md`):
istio, inference, training, fine-tuning, kubeflow (the kubeflow brief produces
several small courses). To build one, open a new session in this folder and say:
"Build the course described in courses/<name>/BUILD.md". Suggested order:
istio, training, inference, fine-tuning, kubeflow.

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

## Installed on this machine

- Homebrew: `k3d`, `helm`
- Docker: k3d cluster `kdrill`; image `kdrill.local/karpenter-kwok:v1.15.1-kdrill.1` (42 MB)
- `~/.kdrill/` (state, kubeconfig), `~/.cache/kdrill/` (Karpenter source, 21 MB)

## Memory

The k3s node grows as courses install CRDs and does not shrink on `course stop`.
After working through several courses, run `kdrill cluster down && kdrill cluster up`
to get the memory back. Keep one heavy course started at a time.

## Known gaps

- Only spot-checked by the orchestrating session: k8s-scheduling 05/06, gpu-scheduling 07/10, karpenter 01, kyverno 01, envoy 01/25. Every lesson was run end to end by the agent that wrote it, on a separate test cluster.
- `kdrill course stop` does not clean up an active lesson first.
- Lesson cleanup takes 20–30 s (namespace deletion), so `reset` is slow.
- Envoy lessons 15, 28, 32, 33, 35 take 10–18 s to verify (Envoy cluster warm-up, log flush, token refill); each README says so.
- Shared traffic/TLS helpers live in `courses/envoy/lib.sh`; later real-traffic courses should promote them to `base/lib/common.sh`.
- `kdrill next` moves on even if the current lesson isn't verified.
