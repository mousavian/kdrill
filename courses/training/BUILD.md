# BUILD brief — `training` course

You are building one kdrill course in a fresh session. Read, in this order,
before writing anything:

1. `hack/COURSE_AUTHORING.md` — layout, limits, quality bar, test cycle, and the
   section "Building from a BUILD.md brief" (your permissions and hand-off).
2. `DESIGN.md`, `README.md`, `STATUS.md`, `base/lib/common.sh`, `base/images/README.md`.
3. `courses/gpu-scheduling/` in full — it already teaches GPU requests, Kueue
   quotas, gang admission and preemption on *fake* nodes. Do not repeat it;
   this course runs *real* training processes.
4. Whichever real-container course exists (`courses/envoy`) for how real pods
   are set up, waited for and checked.

## Goal

A learner who finishes can run model training on Kubernetes as a batch workload
and keep it alive: package it as a Job, give it data and a place for
checkpoints, survive pod kills and node drains by resuming, run it distributed
across pods, and queue it. The model is deliberately tiny (a character-level GPT
with a few hundred thousand parameters on CPU); the Kubernetes mechanics are
the same ones used for large GPU jobs, and every lesson's README says how the
real-cluster version differs.

- Directory: `courses/training`, `kind: real-compute`,
  `requires: [k8s-scheduling, gpu-scheduling]` (informational).
- No lesson cap.

## Machine constraints that shape this course

8 GB Mac, Docker VM 4 GB, one k3s node, CPU only, arm64. Budget for the course's
components plus a lesson's pods: about 1.5 GB.

- **One shared image**, `kdrill.local/ml-tiny:<version>`, defined in
  `base/images/ml-tiny/` (see `base/images/README.md`). If it does not exist yet,
  you create it; if it exists, reuse and extend it without breaking other
  courses. CPU-only PyTorch arm64 wheel, no CUDA packages, no downloads at
  lesson time, bundled small text corpus. A component (`ml-tiny-image`) runs its
  `build.sh` on course start so the image is in the cluster.
- A default training run must finish in **1–3 minutes** on 2 CPUs and stay under
  ~600 MB RSS. Distributed lessons use 2 workers, each smaller. Set
  `OMP_NUM_THREADS`/`torch.set_num_threads` from the CPU limit, otherwise PyTorch
  oversubscribes and everything crawls.
- Storage: k3s `local-path` StorageClass (ReadWriteOnce, node-local) is all there
  is. That is enough on a single node; say in READMEs what a multi-node cluster
  needs instead (RWX filesystem or object storage).
- Object storage: a single small MinIO pod is acceptable for the lessons that
  need S3 semantics (measure it; keep it a lesson-level workload or a small
  component). If it does not fit, use a PVC and explain the difference.
- The training script must be **instrumented for the lessons**: flags or env for
  steps, checkpoint interval, checkpoint directory, resume, seed, fail-at-step
  (to trigger failures on demand), SIGTERM handling, and it must write
  machine-readable progress (`metrics.json` with step and loss) that verify can read.

## Components

- `ml-tiny-image` (build + `k3d image import`), shared with later courses.
- `jobset` (pinned release manifest) for the JobSet lessons.
- `kueue` already exists under `base/components/kueue` — reuse it.
- KubeRay / Kubeflow Trainer are **not** part of this course (Trainer belongs to
  the `kubeflow` course). A KubeRay lesson is optional and only if a Ray head
  plus one worker measurably fits; otherwise mention it under "On a real cluster".

## Proposed lesson outline (a starting point — reorder, split, add)

Part A — a training run as a Job
1. Run training as a Job: command/args, `restartPolicy`, completions; read the
   loss from logs. Starts with a Deployment that restarts forever (wrong tool).
2. Size it: CPU/memory requests and limits; an OOMKilled run (batch size too
   large) that the learner must diagnose and fix; thread count vs CPU limit.
3. Configuration: hyperparameters through env / ConfigMap; reproducible runs with a seed.
4. Data in: dataset from a ConfigMap is too small — mount a PVC populated by an
   init container / a data-prep Job.

Part B — don't lose work
5. Checkpoints to a PVC: the run writes checkpoints; a second Job samples text
   from the result.
6. Kill and resume: delete the pod mid-run; the Job's replacement pod must
   continue from the last checkpoint, not step 0 (verify compares step counters).
7. Failure policy: `backoffLimit`, `podFailurePolicy` — retry on disruption
   (exit from SIGTERM / DisruptionTarget) but fail fast on a real bug (a specific
   exit code). `activeDeadlineSeconds`, `ttlSecondsAfterFinished`.
8. Graceful preemption: handle SIGTERM, write a final checkpoint inside
   `terminationGracePeriodSeconds` (the spot-instance / drain case). Verify sends
   the eviction and checks a checkpoint newer than the signal exists.
9. Checkpoints to object storage (MinIO): credentials from a Secret; resume from S3.

Part C — more than one pod
10. Hyperparameter sweep with an Indexed Job (`completionMode: Indexed`,
    `parallelism`), each index a different learning rate; collect the best run.
11. Distributed training by hand: Indexed Job + headless Service, stable pod
    hostnames, 2 workers with PyTorch DDP on CPU (gloo backend), rank from
    `JOB_COMPLETION_INDEX`. Starts broken (no headless service / wrong subdomain).
12. All-or-nothing: what happens when one worker dies; restarting the group.
13. JobSet: the same job as a `JobSet` with replicated jobs, DNS, success policy
    and failure policy (restart the whole set).
14. Sharing data and checkpoints across workers (only rank 0 writes; RWO
    limits; why real clusters use RWX or object storage).

Part D — queueing real jobs
15. Kueue with a real job: `suspend`, LocalQueue, admission, then it runs. Quota
    sized so only one training job runs at a time; the second waits and then starts.
16. Priority: a high-priority short job preempts a long run, which resumes from
    its checkpoint afterwards (ties Part B and Part D together).
17. Gang admission for the JobSet from lesson 13 (all workers or none).

Part E — operating it
18. Watching a run: progress from logs/metrics file, exposing step and loss as a
    Prometheus text endpoint, events; finding out why a run is slow (CPU throttling).
19. Results as artifacts: where the final model goes, naming/versioning runs, and
    cleaning up finished Jobs and old checkpoints.
20. Capstone: a resumable, queued, 2-worker run with a failure policy and a
    planted fault, ending in a model that a sampling Job can load.

## How verify should work

- Assert on outcomes read from the cluster: Job conditions, pod exit codes and
  termination reasons, restart counts, files on the PVC (read through a short
  helper pod or `kubectl exec`), `metrics.json` contents (resumed step > 0,
  final loss below a loose threshold, both workers contributed).
- Loss thresholds must be loose and seed-fixed; never assert exact numbers.
- Guard against cheats: lowering steps so nothing needs resuming, removing the
  fault flag from the script instead of configuring the Job, running one worker
  when two are required, deleting the queue instead of using it.
- Runs take minutes: setup starts them; README states expected wait; verify
  polls with a clear message instead of failing while a run is still in progress.

## Known traps

- PyTorch CPU wheels for arm64 come from PyPI directly (the `+cpu` index is for
  x86) — verify, and check the image size.
- PVC `local-path` binds on first consumer; a helper pod reading the volume
  while the Job runs is fine on one node but hides RWO problems — say so.
- KWOK fake nodes may exist from other courses: real pods must never land on
  them (the engine handles the taint for `sim`; for real kinds add node affinity
  or check how `courses/envoy` did it).
- Namespace cleanup with PVCs is slow; keep volumes tiny.
- Pod deletion vs eviction produce different conditions (`DisruptionTarget`);
  `podFailurePolicy` lessons depend on using the right one.

## Check upstream before relying on it

JobSet current release and API version; Kueue version already pinned in
`base/components/kueue` and its JobSet integration flag; `podFailurePolicy` /
`successPolicy` field status on Kubernetes v1.35; MinIO image tag and arm64 support.

## Done means

Every lesson passes the full test cycle in `hack/COURSE_AUTHORING.md`; course
stop/start is clean; image and footprint are measured and written in STATUS.md;
this file is deleted; committed to `main`.
