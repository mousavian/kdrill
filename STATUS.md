# kdrill status

Last updated: 2026-11-14

## Courses

| Course | Lessons | Extra components | Notes |
|---|---|---|---|
| k8s-scheduling | 6 | – | start here |
| gpu-scheduling | 12 | kueue, gpu-binpack-scheduler, kwok-job-runtime | all simulated on fake nodes |
| karpenter | 12 | karpenter-kwok (built from source, needs Go + helm) | first `course start` builds an image (~90 s) |
| kyverno | 13 | kyverno (helm) | ~1 GB extra RAM while installed; lessons 08 and 12 need internet |

Not built yet (see DESIGN.md §8): envoy, istio, inference, training, fine-tuning.

## Decisions made without you — review these

1. **Kyverno has 13 lessons** (you asked for 10–20; the brief said 10–12). Lesson 08 (verify-images) is the easiest to drop.
2. **Kyverno teaches the classic `ClusterPolicy`** in 11 of 13 lessons, although Kyverno v1.19 marks it deprecated; lesson 11 teaches the CEL replacement (`ValidatingPolicy`).
3. **Karpenter is patched** (one line, `base/components/karpenter-kwok/kwok-node-capacity.patch`): upstream's KWOK provider reports a fake node's capacity as the pod requests that triggered it, which breaks NodePool limits. The patch makes nodes report the instance type's full capacity.
4. **Karpenter's instance catalogue is hand-written** (`base/components/karpenter-kwok/catalog.txt`): 36 types, prices approximate.
5. **Bin-packing uses a second scheduler** (`schedulerName: gpu-binpack`) rather than changing the default scheduler's profile.
6. **Kueue's visibility API is removed at install**, because it makes `kubectl api-resources` fail while the controller restarts and the engine's cleanup depends on that command.
7. **Lesson cleanup in the kyverno and karpenter courses deletes every policy / NodePool in the cluster**, not only the lesson's.
8. **Fake Job pods**: KWOK normally completes Job pods instantly; the `kwok-job-runtime` component makes them honour a delay annotation so training Jobs appear to run.

## Installed on this machine

- Homebrew: `k3d`, `helm`
- Docker: k3d cluster `kdrill`; image `kdrill.local/karpenter-kwok:v1.15.1-kdrill.1` (42 MB)
- `~/.kdrill/` (state, kubeconfig), `~/.cache/kdrill/` (Karpenter source, 21 MB)

## Memory

The k3s node grows as courses install CRDs and does not shrink on `course stop`.
After working through several courses, run `kdrill cluster down && kdrill cluster up`
to get the memory back. Keep one heavy course started at a time.

## Known gaps

- Only spot-checked on the main cluster: k8s-scheduling 05/06, gpu-scheduling 07/10, karpenter 01, kyverno 01. Every lesson was run end to end by the agent that wrote it, on a separate test cluster.
- `kdrill course stop` does not clean up an active lesson first.
- Lesson cleanup takes 20–30 s (namespace deletion), so `reset` is slow.
- `kdrill next` moves on even if the current lesson isn't verified.
