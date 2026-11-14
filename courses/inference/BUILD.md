# BUILD brief — `inference` course

You are building one kdrill course in a fresh session. Read, in this order,
before writing anything:

1. `hack/COURSE_AUTHORING.md` — layout, limits, quality bar, test cycle, and the
   section "Building from a BUILD.md brief" (your permissions and hand-off).
2. `DESIGN.md`, `README.md`, `STATUS.md`, `base/lib/common.sh`, `base/images/README.md`.
3. `courses/envoy/` in full — real traffic, client helpers, and the Envoy Gateway
   component this course reuses for model-aware routing. If it has a bridging
   lesson on inference routing, continue from it rather than repeating it.
4. `courses/gpu-scheduling/` and `courses/karpenter/` — fake GPU nodes, Kueue,
   node provisioning. The "at scale" half of this course builds on them.

## Goal

A learner who finishes can put an LLM behind an API on Kubernetes and operate
it: get the model onto the node, make startup and readiness honest, size it,
read the metrics that matter (time to first token, tokens per second, queue
depth, cache use), autoscale on those instead of CPU, route requests by model
and by load, roll out new versions without dropping requests, and reason about
GPU capacity for a fleet. Half the course runs a real tiny model on CPU; the
other half uses a model-server simulator and fake GPU nodes for the things that
only show up at scale.

- Directory: `courses/inference`. Course default `kind: real-compute`; fleet
  lessons set `kind: sim` in `lesson.yaml`. `requires: [envoy, gpu-scheduling]`.
- No lesson cap.

## Three ways lessons get a "model server" (pick per lesson)

1. **Real tiny LLM**: llama.cpp's HTTP server (OpenAI-compatible
   `/v1/chat/completions`, `/health`, Prometheus `/metrics`) with a very small
   GGUF model (order of 100 MB, e.g. a ~135M-parameter model at 4-bit). Real
   tokens, real load time, real streaming. **Verify**: an official multi-arch
   (arm64) server image and its pinned tag/digest; a small GGUF with a
   permissive licence and a stable URL + sha256; that `/metrics` exists and which
   flag enables it. The model file is downloaded **once** by the component into
   a location lessons mount (a hostPath inside the k3d node or a pre-populated
   PVC), checksum-verified — lessons never download. If no suitable real model
   fits, fall back to the tiny GPT server from `base/images/ml-tiny` and record it.
2. **Model-server simulator** for load-dependent behaviour: a small server that
   speaks the same API and exposes vLLM-style metrics (requests running,
   requests waiting, KV-cache usage, TTFT, loaded LoRA adapters) with
   configurable latency and capacity. An upstream simulator from the llm-d
   project (`llm-d-inference-sim`) is believed to exist with arm64 images —
   **verify and pin it**; if it does not fit, write a ~150-line one into `ml-tiny`.
   It needs almost no memory, so 3–6 replicas are fine.
3. **Fake pods on fake GPU nodes** (`kind: sim`) for capacity and scheduling
   questions where no request is ever served.

Every README says which of the three it uses and how a real vLLM / TGI / Triton
deployment on GPUs differs.

## Machine constraints

8 GB Mac, Docker VM 4 GB, one k3s node, CPU only, arm64. Budget: about 1.5 GB for
components plus a lesson's pods. One real model replica at a time (cap threads
and context size; measure RSS). Autoscaling lessons use the simulator.
There is **no Prometheus and no metrics-server** in the cluster:

- Prefer **KEDA** with a trigger that reads a metric straight from an HTTP
  endpoint (the `metrics-api` scaler) so no Prometheus is needed. Verify the
  scaler and whether it can read what the simulator exposes (it wants JSON; add a
  JSON endpoint to the simulator or a 20-line adapter if needed).
- Only add a minimal single-pod Prometheus (short retention, tiny requests) if a
  lesson truly needs PromQL, and measure it.
- If a lesson needs resource metrics (CPU-based HPA as the "wrong way"),
  metrics-server must be installed as a component; measure it.

## Components (expected; confirm each)

- `inference-models` — downloads and verifies the GGUF, makes it mountable; imports images.
- `keda` — pinned, minimal.
- Envoy Gateway + Gateway API CRDs — **reuse the envoy course's component**.
- Gateway API Inference Extension — CRDs + an endpoint picker. The API has
  changed between releases (`InferencePool`, `InferenceModel` → `InferenceObjective`,
  version bumps) and so has Envoy Gateway's support for it. **Pin a matching
  pair of versions from their docs and test it for real**; teach whatever the
  pinned version actually calls things.
- `kueue`, `kwok` already exist; reuse for the sim lessons.
- KServe is **not** in this course (it belongs to `kubeflow`); mention it under
  "On a real cluster".

## Proposed lesson outline (a starting point — reorder, split, add)

Part A — serve a model
1. First completion: a Deployment + Service for the real server; call the
   OpenAI-compatible API from a client pod. Starts with wrong args/port.
2. Getting weights to the pod: baked into the image vs init-container download
   vs shared volume / node cache; why image size and pull time matter. If image
   volumes (OCI artifact as a volume) work on k3s v1.35, add a lesson on them.
3. Honest startup: `startupProbe` for slow model load, `readinessProbe` on real
   health, not on "port open". Starts with a pod that is killed mid-load.
4. Sizing: memory = weights + context; an OOMKilled server; threads vs CPU
   limit; what the same sizing question looks like for GPU memory.
5. Streaming and timeouts: server-sent events through a Service/gateway;
   idle timeouts that cut long generations.
6. The metrics that matter: TTFT, tokens/s, queue length, context/KV-cache use —
   read them from `/metrics` while sending load.
7. Server-side concurrency: parallel slots / batching, and what it does to
   latency vs throughput (measured with the simulator or real server).

Part B — scale it
8. Why CPU-based HPA is wrong for model servers (shown, then replaced).
9. Autoscale on queue depth / in-flight requests with KEDA; scale-up and
   scale-down behaviour, stabilisation windows.
10. Cold starts: scale-from-zero cost (load time), keeping a warm minimum,
    pre-pulled images and cached weights.
11. Graceful shutdown: `preStop` + `terminationGracePeriodSeconds` so in-flight
    generations finish during scale-down and rollouts (verify: zero failed
    requests under load while replicas change).
12. Rollouts when capacity is scarce: `maxSurge: 0` vs surge, PodDisruptionBudget,
    readiness gates (uses the simulator; then repeated on fake GPUs in Part D).

Part C — route it
13. One endpoint, several models: route by the `model` field in the request
    body (Gateway + body-based routing as provided by the pinned versions).
14. Why round-robin is bad for LLMs; least-request balancing as a first step.
15. Load-aware routing with the Gateway API Inference Extension: an
    `InferencePool` and endpoint picker that prefers replicas with shorter queues
    and free KV-cache. Verify by loading one replica and showing traffic avoids it.
16. LoRA adapters as "models": route by adapter name to replicas that have it loaded.
17. Priorities / criticality: shed or queue low-priority traffic when saturated.
18. Protecting the fleet: per-client rate limits or token budgets at the gateway;
    canary a new model version by weight.

Part D — the fleet at GPU scale (`kind: sim`)
19. Replicas on fake GPU nodes: right GPU type via node labels/affinity; one
    GPU per replica; what Pending looks like when GPUs run out.
20. Packing small models: fractional GPUs (time-slicing / MIG labels from the
    gpu-scheduling course) vs dedicated GPUs.
21. Inference vs training on shared GPUs: priority and preemption so serving
    wins; Kueue quota with borrowing.
22. Rolling a model version when every GPU is in use (ties to lesson 12).
23. Spreading replicas across zones / nodes; surviving a node loss.
24. Capacity math: from target requests/s and tokens/s per GPU to a replica
    count, and the autoscaler bounds that follow (verify checks the numbers).
25. Scale-to-zero for rarely used models and what it costs (node provisioning +
    image pull + load) — with Karpenter fake nodes if that component fits alongside.

Capstone
26. A two-model service with load-aware routing, queue-based autoscaling,
    honest probes and zero-drop rollouts, with planted faults.

## How verify should work

- Send real requests from a client pod; assert on status codes, which replica
  or model answered (response headers/fields), streamed chunks arriving, and
  error counts under a short load run.
- Read metrics endpoints directly for metric-based checks; read HPA/ScaledObject
  status and replica counts for scaling (poll; scaling takes tens of seconds —
  say so in the README and keep cooldowns short in lesson manifests).
- For routing, make the difference large (one replica saturated via its admin
  knobs) and assert a wide margin, never an exact split.
- Guard against cheats: fixed replica counts instead of autoscaling, removing
  the slow-load behaviour instead of fixing probes, routing everything to one model.
- Real generation is slow on this CPU: cap `max_tokens` (8–16) in every check.

## Known traps

- KEDA and a hand-made HPA on the same Deployment fight each other.
- Body-based routing needs the gateway to buffer the request; streaming
  responses must still pass through.
- Port-forward breaks long streams; use in-cluster clients for checks.
- Real pods must never land on KWOK fake nodes; fake pods must never land on the real node.
- Course components overlap with `envoy` and `gpu-scheduling`: starting this
  course must work whether or not those courses are currently started, and
  stopping it must not remove components another started course still needs
  (check how the engine tracks components; fix the engine if it does not handle this).

## Check upstream before relying on it

llama.cpp server image, flags and metric names; the GGUF model URL, licence and
checksum; llm-d inference simulator image and flags; KEDA version and
`metrics-api` scaler parameters; Gateway API Inference Extension release and the
Envoy Gateway version that supports it; ImageVolume status on k3s v1.35.

## Done means

Every lesson passes the full test cycle in `hack/COURSE_AUTHORING.md`; course
stop/start is clean, including next to `envoy`; footprint, downloads and
anything left on the machine are written in STATUS.md; this file is deleted;
committed to `main`.
