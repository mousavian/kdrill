# kdrill — design

A local, hands-on Kubernetes practice lab. Topics are packaged as **courses**,
each course is a sequence of **lessons**, and each lesson gives you a goal, a
prepared cluster state, and a `verify` command that tells you exactly what is
still wrong. Courses can be added at any time without touching the core.

Status: draft, pre-build. Mark up anything that's off.

---

## 1. Goals and non-goals

**Goals**
- Learn by doing against a *real* Kubernetes control plane with your own `kubectl`.
- Topic-modular: add a course (Istio, Karpenter, …) as a folder of files; track progress per course.
- Every lesson has the same loop: `start → (you work) → verify → cleanup/reset → next`.
- Fits on an **8 GB Apple Silicon Mac**. Default to the lightest option everywhere.
- Simulate what's impossible locally (GPUs, big fleets, cloud nodes); run for real what fits (traffic, policy, tiny-model training).

**Non-goals (for now)**
- Production-grade anything. Small and understandable beats complete.
- Real GPU/CUDA/NCCL work — covered later on a rented GPU box if wanted.
- Web UI. CLI first; a web view can be added per course/lesson later on the same engine.

---

## 2. Machine budget

Measured host: Apple Silicon (arm64), 8 cores, 8 GB RAM, Docker Desktop installed.

- Container VM limit: **~4 GB** (leave the rest for macOS + editor/browser).
  OrbStack or Colima use noticeably less idle memory than Docker Desktop and are worth trying.
- Cluster: **k3d (k3s in Docker)**, one server node by default. Extra agent nodes only when a lesson needs them.
- **One heavy course active at a time.** Starting a course installs its components; `kdrill course stop` uninstalls them to free memory.
- All images arm64, slim variants; cached in a local registry so resets don't re-download.

Rough footprints (to be measured during build — these are estimates):

| Component | Approx. RAM | Notes |
|---|---|---|
| k3s server (1 node) | 500–700 MB | Traefik and other extras disabled |
| KWOK controller + fake nodes | ~50 MB | Fake nodes/pods cost ~nothing |
| Kyverno (admission only) | 300–400 MB | Background/reports/cleanup controllers off |
| Karpenter (KWOK provider) | ~200 MB | |
| Kueue | ~100 MB | |
| Istio (ambient or minimal) | 0.6–1 GB | Biggest of the "light" courses |
| Envoy Gateway | ~300 MB | |
| Training/fine-tune pod | 0.5–1.5 GB | Tiny models only, CPU |

A `profile` setting (`lite` default, `full` when you have a bigger machine)
lets lessons scale replica counts, model size, and node counts.

---

## 3. Cluster shape: three kinds of lesson

One cluster, mixed nodes. Each lesson declares which kind it needs; setup arranges it.

| Kind | Nodes | Used by |
|---|---|---|
| **sim** | KWOK fake nodes (incl. fake GPU nodes) | GPU scheduling, Karpenter, scale/capacity, GPU-scale inference |
| **real-light** | Real k3s node(s), real containers + traffic | Istio, Envoy, Kyverno |
| **real-compute** | Real k3s node, CPU+memory budget | Training, fine-tuning, real (tiny) inference |

Fake nodes are tainted (`kdrill.dev/fake=true:NoSchedule`) so real workloads
never land on them by accident; sim lessons add the toleration.

**Fake GPUs** are modelled two ways (both run through the *real* scheduler):
- Extended resources: node capacity `nvidia.com/gpu: 8` + GPU-feature-discovery-style labels (`nvidia.com/gpu.product`, MIG labels).
- DRA: fake `ResourceSlice`s published for fake nodes, so `ResourceClaim` allocation can be practiced.

**Inference simulator** (later): one small process that serves Prometheus metrics
for fake model-server pods (queue depth, tokens/s, KV-cache %, TTFT) from a load
model, so autoscaling and routing can be practiced at "GPU scale".

---

## 4. Repository layout

```
kdrill/
  cmd/kdrill/            # Go CLI
  internal/              # engine: cluster, courses, state, runner
  base/
    cluster/             # k3d config, registry, KWOK install
    components/          # reusable installs, each with install/uninstall/check
      kwok/  kyverno/  karpenter-kwok/  kueue/  istio/  envoy-gateway/  minio/ ...
    lib/
      check.sh           # helpers for verify scripts (see §6)
  courses/
    <course>/
      course.yaml
      setup.sh           # optional: once per course (install components)
      teardown.sh        # optional: uninstall course components
      lessons/
        01-<slug>/
          lesson.yaml
          README.md      # concept (~5 min read) + the task + doc links
          setup.sh       # put cluster into the lesson's starting state
          verify.sh      # checks; prints ✓/✗ per check
          cleanup.sh     # optional: default cleanup handles most lessons
          hints.md       # progressive hints, separated by ---
          solution/      # reference solution (manifests + notes)
```

Courses are plain files — readable, editable, and easy to generate. No recompiling to add one.

---

## 5. File formats

**course.yaml**
```yaml
id: istio
title: Istio service mesh
description: Sidecars, ambient mode, traffic routing, mTLS, observability.
kind: real-light            # default for lessons; a lesson can override
components: [istio]         # installed on course start, removed on course stop
requires: []                # other courses recommended first (informational)
```

**lesson.yaml**
```yaml
id: 03-strict-mtls
title: Enforce strict mTLS
goal: >
  All traffic in namespace `shop` must be mTLS-only; plaintext from outside the
  mesh must be rejected.
kind: real-light            # sim | real-light | real-compute
nodes: { real: 1, fake: 0 } # what setup ensures exists
timeout: 120s               # max time for setup/verify
concepts: [PeerAuthentication, mTLS modes]
```

---

## 6. Lesson lifecycle and isolation

- Each lesson works in its own namespace(s), labelled `kdrill.dev/lesson=<course>/<id>`.
  Cluster-scoped objects a lesson creates get the same label.
- **setup** — idempotent; ensures nodes/components, applies starting manifests.
- **verify** — runs `verify.sh`, which uses `base/lib/check.sh`:
  ```bash
  check "Pod has an istio-proxy sidecar" \
    kubectl -n shop get pod -l app=web -o jsonpath='{.items[0].spec.containers[*].name}' \| grep -q istio-proxy
  check_eq "PeerAuthentication mode" STRICT \
    "$(kubectl -n shop get peerauthentication default -o jsonpath='{.spec.mtls.mode}')"
  ```
  Output is one line per check (`✓`/`✗` + hint on failure); exit code 0 only if all pass.
- **cleanup** — default: delete everything labelled for the lesson (namespaces + cluster-scoped). `cleanup.sh` only for extras.
- **reset** — cleanup, then setup. Always gets you back to the starting state.
- Course components persist across lessons of that course; removed by `course stop`.

---

## 7. CLI

```
kdrill doctor                 # check docker/runtime, memory limit, tools
kdrill cluster up|down|nuke   # create / stop / delete the local cluster

kdrill courses                # list courses + progress
kdrill course start <course>  # install course components
kdrill course stop  <course>  # uninstall them (free memory)

kdrill start <course>/<nn>    # course start if needed, then lesson setup
kdrill status                 # current lesson, goal, nodes/kind
kdrill hint                   # next hint (progressive)
kdrill verify                 # run checks
kdrill reset                  # back to lesson starting state
kdrill cleanup                # remove lesson resources
kdrill next                   # cleanup + start next lesson
kdrill solution               # show reference solution
```

**State**: `~/.kdrill/state.json` — active lesson, per-course progress
(completed lessons, timestamps), hints revealed. Courses progress independently.

**Implementation**: Go CLI, shells out to `kubectl`/`helm`/`k3d` and runs lesson
scripts with a known environment (`KDRILL_LESSON`, `KDRILL_NS`, `KDRILL_PROFILE`,
path to `check.sh`). Course files are read from disk (can be embedded with
`go:embed` later for a true single binary).

---

## 8. Courses (roadmap)

Lesson lists are first drafts; each course gets 10–20 lessons when built.

**k8s-scheduling** (sim) — the base course that validates the engine
requests/limits & QoS · nodeSelector/affinity · taints/tolerations · topology spread ·
priority & preemption · extended resources (fake GPUs) · bin-packing vs spread · why-is-it-Pending debugging

**gpu-scheduling** (sim)
GPU node labels/feature discovery · whole-GPU requests · MIG profiles · time-slicing ·
DRA ResourceClaims/DeviceClasses · gang scheduling with Kueue · quotas/cohorts · preemption of training by inference

**karpenter** (sim, KWOK provider)
NodePools/NodeClasses · provisioning on pending pods · instance-type selection incl. GPU types ·
consolidation · disruption budgets · drift · spot vs on-demand · limits

**kyverno** (sim or real-light)
validate · mutate · generate · verify images · policy exceptions · audit vs enforce · policy reports

**envoy** (real-light)
Envoy basics (listeners/clusters/routes) · Envoy Gateway + Gateway API · traffic splitting ·
retries/timeouts · rate limiting · auth · later: Gateway API Inference Extension

**istio** (real-light; ambient/minimal to save memory)
injection/ambient · VirtualService/DestinationRule · canary · fault injection · mTLS · AuthorizationPolicy · observability

**inference** (real-compute tiny + sim at scale)
serve a tiny model on CPU · readiness/startup probes for model loading · autoscaling on custom metrics ·
KV-cache/queue-aware routing · simulated GPU fleet: right-sizing, scale-to-zero, cold starts

**training** (real-compute, tiny)
train a tiny char-level GPT as a Job · checkpoint to PVC/MinIO · kill & resume ·
2-pod distributed training with torchrun (gloo/CPU) · Kubeflow Trainer / JobSet · KubeRay RayJob · Kueue gang admission

**fine-tuning** (real-compute, tiny)
LoRA fine-tune of the model trained in the training course (no big downloads) ·
datasets from MinIO · artifacts & versioning · serve the fine-tuned model · compare base vs tuned

---

## 9. Build plan

1. **Engine + base** — CLI skeleton, `doctor`, `cluster up/down`, KWOK + fake-node support, state, lesson runner, `check.sh`.
2. **k8s-scheduling course** (~5 lessons first) — proves the full start/verify/reset loop end to end.
3. Remaining courses one at a time, cheapest first: kyverno → karpenter → gpu-scheduling → envoy → istio → inference → training → fine-tuning.
4. Measure real memory per course and tune the `lite` profile.
5. Optional later: web view (terminal + live cluster/GPU map) per course or lesson.

## 10. Open questions
- Container runtime: stay on Docker Desktop, or switch to OrbStack/Colima for memory?
- Lesson README language/depth: is "~5 min concept + task + doc links" the right size once you see one?
