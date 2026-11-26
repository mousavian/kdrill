# BUILD brief — Kubeflow courses

**Queue check first:** open `courses/QUEUE.md`. Build the first course listed
there that still has a `BUILD.md`. If that is not this one, stop reading this
file and open that course's brief instead.

**Progress:** Course 1 (`kubeflow-trainer`) is **built** (11 lessons, Trainer v2.4.0; see STATUS.md and
"Notes from building Course 1" at the end of this file). Continue with Course 2 (`kubeflow-kserve`);
do not rebuild Course 1. Keep this file until the last Kubeflow course is built.

You are building kdrill course material in a fresh session. Read, in this
order, before writing anything:

1. `hack/COURSE_AUTHORING.md` — layout, limits, quality bar, test cycle, and the
   section "Building from a BUILD.md brief" (your permissions and hand-off).
2. `DESIGN.md`, `README.md`, `STATUS.md`, `base/lib/common.sh`, `base/images/README.md`.
3. `courses/training-platform/` (or `courses/training/` before the rename), `courses/inference/`, `courses/llm-from-zero/` and `courses/fine-tuning/` if built —
   Kubeflow wraps the mechanics those courses teach by hand. Reuse the `ml-tiny`
   image, its training script and the model servers; do not fork them.
4. `courses/kyverno/` for a helm/manifest-installed component with webhooks
   and clean uninstall.

## Goal

A learner who finishes knows what each Kubeflow project is for, can use the
main ones through their CRDs, and understands what they add over plain
Jobs/Deployments. Kubeflow is a set of separate projects; the full platform
(dashboard, profiles, notebooks, Istio, Dex) does not fit on this machine and
is not installed.

## The key decision: several small courses, not one

The engine installs all of a course's components on `course start`, and
Kubeflow's projects together need far more than the ~1.5 GB budget. So this
brief produces **one course per project**, each with its own components, built
and committed **one after another** (this is the one exception to "one course
per session"; you may also stop after any of them and leave the rest):

| Order | Course dir | Project | Fit on this machine |
|---|---|---|---|
| 1 | `courses/kubeflow-trainer` | Kubeflow Trainer (v2: `TrainJob`, runtimes) | **BUILT** (fits: controller about 60 MB) |
| 2 | `courses/kubeflow-kserve` | KServe (`InferenceService`) in its no-Knative deployment mode | expected to fit; check cert-manager need |
| 3 | `courses/kubeflow-katib` | Katib (`Experiment`, `Suggestion`, `Trial`) | uncertain: needs a database; measure |
| 4 | `courses/kubeflow-pipelines` | Kubeflow Pipelines | probably too heavy (API server, DB, object store, workflow controller); measure before committing to it |

After the last one, replace this directory with either nothing (delete
`courses/kubeflow`) or a short `README.md` that maps the Kubeflow projects to
the kdrill courses. Record in STATUS.md which projects were built, which were
skipped and why, and what was not attempted (Notebooks, Model Registry,
Spark Operator, central dashboard / profiles / multi-tenancy).

For anything that does not fit: first try the leanest install (single replicas,
smallest DB, optional controllers off, requests cut down). If it still does not
fit, a read-only lesson set is **not** an acceptable substitute — skip
the course and say so. Every kdrill lesson must be hands-on and verifiable.

No lesson cap in any of them.

## Machine constraints

8 GB Mac, Docker VM 4 GB, one k3s node (v1.35.x), CPU only, arm64. Every image
must have an arm64 variant — several Kubeflow images historically did not;
check each one before designing lessons around it. Training runs use the
`ml-tiny` image and finish in 1–3 minutes. Memory does not come back after
`course stop` until the cluster restarts; restart the dev cluster between courses
when measuring.

## Course 1 — `kubeflow-trainer`

Components: `jobset` (reuse if `training` created it), `kubeflow-trainer`
(controller + CRDs, pinned release manifests), `ml-tiny-image`, `kueue` (reuse).
Do **not** install the stock runtimes that reference large upstream images;
lessons define their own runtimes around `ml-tiny`.

Outline (starting point):
1. From Job to `TrainJob`: run the tiny training through a `ClusterTrainingRuntime`;
   see the JobSet and Jobs it creates. Starts with a TrainJob pointing at a
   runtime that does not exist.
2. Runtimes vs jobs: platform team owns the runtime (image, launcher, policy),
   user owns the TrainJob (args, resources, node count). Write a namespaced
   `TrainingRuntime`.
3. Overriding the trainer: image, command/args, env, resources per node.
4. Distributed PyTorch: `numNodes: 2`, how rank/world size/master address reach
   the pods (which env vars the pinned version injects — verify), DDP on CPU.
5. Datasets and models as initializers (if the pinned version supports
   initializer steps without large images; otherwise a PVC-based equivalent
   through `podTemplateOverrides` or the version's equivalent field).
6. Checkpoints and resume with a PVC under a TrainJob; what restarts mean for a JobSet.
7. Failure and suspension: `suspend`, failure conditions, cleaning up.
8. Kueue + TrainJob: queue label, admission, quota (check that the pinned Kueue
   supports TrainJob; enable the integration in the kueue component if needed
   without breaking the gpu-scheduling course).
9. Scheduling policy on fake GPU nodes (`kind: sim`): a multi-node TrainJob
   requesting `nvidia.com/gpu`, gang behaviour, what Pending looks like.
10. Legacy `PyTorchJob` (Training Operator v1) — reading-level comparison inside
    a lesson README only, plus migrating one v1 manifest to a TrainJob as the task.
11. Capstone: a runtime + queued, resumable 2-node TrainJob with a planted fault.

## Course 2 — `kubeflow-kserve`

Components: KServe controller + CRDs in the deployment mode that needs no
Knative (called RawDeployment / "Standard" depending on version — verify), its
certificate dependency (cert-manager, or self-signed certs if supported), and
ingress disabled or pointed at the Gateway API only if the envoy component is
reused. Model storage: a PVC or a tiny in-cluster HTTP/MinIO store populated in
setup — no cloud buckets, no large downloads.

Outline (starting point):
1. First `InferenceService` with a custom predictor container (the tiny model
   server); see the Deployment/Service KServe creates; call it.
2. Storage initializer: `storageUri` from a PVC (and S3-style from MinIO with
   a service account secret); the model arrives in `/mnt/models`.
3. `ServingRuntime` / `ClusterServingRuntime`: separate "how to serve" from
   "which model"; write one for the tiny server. For an LLM lesson, a runtime
   around the llama.cpp server if the `inference` course's model component exists.
4. The inference protocol (v1/v2 or OpenAI-compatible, as the pinned version
   offers) — readiness, model metadata, predict.
5. Probes, resources and model-load time under KServe.
6. Autoscaling in this mode (HPA, or KEDA if the version supports it), min/max replicas.
7. Canary rollout: `canaryTrafficPercent` — verify whether it works without
   Knative on the pinned version; if not, teach the supported rollout path and say why.
8. Transformer + predictor (pre/post-processing container in front of the model).
9. Multi-model: `InferenceGraph` or ModelMesh-style serving only if it fits and
   has arm64 images; otherwise leave out.
10. Debugging a failed InferenceService: conditions, storage-initializer logs,
    webhook rejections; planted faults.
11. Capstone.

## Course 3 — `kubeflow-katib` (only if it fits)

Components: Katib controller, DB manager and the smallest database it
supports, metrics collection via stdout/file collector (no extra services).
Suggestion pods are created per experiment — measure them.

Outline: 1. First `Experiment` (random search over learning rate for the tiny
GPT, objective = final loss printed by the script) → 2. Trial templates and
parameter substitution → 3. Metrics collectors (stdout format vs file) → 4.
Search algorithms (grid, random, Bayesian) on a tiny budget → 5. Parallelism,
max trials, failed-trial limits, resource use → 6. Early stopping (median stop)
→ 7. Reading results and re-running the best trial → 8. Katib with a TrainJob or
plain Job as the trial worker → 9. Kueue quota around trials → 10. Capstone.
Compare, in a README, with the Indexed-Job sweep from the `training` course.

## Course 4 — `kubeflow-pipelines` (only if it fits)

Try the standalone install trimmed to one replica each, smallest DB and object
store. Pipelines are compiled with the `kfp` SDK: lessons ship **pre-compiled
pipeline YAML** so the learner needs no Python on the host, and may add an
optional step that compiles inside a pod. Outline: components and a two-step
pipeline → parameters and artifacts → caching → conditionals and loops →
resource requests per step → a prep → train → eval → gate pipeline reusing the
fine-tuning course's steps → recurring runs → debugging a failed step.
If it does not fit, skip it and record the measured numbers.

## How verify should work (all courses)

- Assert on CR status conditions, the child objects created, pod exit codes,
  files/metrics produced by the run, and real requests for serving lessons.
- Guard against cheats: creating the child Job/Deployment by hand instead of
  the CR, pointing at a pre-made result, shrinking the experiment to one trial.
- Runs take minutes: README states the wait; verify polls with a clear message.

## Known traps

- Webhooks with no backend block namespace cleanup and `course stop`; uninstall
  order matters (CRs → controllers → webhooks → CRDs). Test stop/start twice.
- Several projects ship cert-manager or their own cert jobs; never leave two
  copies installed by different courses.
- CRD-heavy installs grow k3s memory permanently until restart.
- Version skew: Trainer needs a specific JobSet; Kueue integrations are
  version-gated; KServe pins Gateway API/cert-manager ranges.
- Real pods must never land on KWOK fake nodes, and sim lessons must tolerate
  the control-plane taint handling described in `hack/COURSE_AUTHORING.md`.

## Check upstream before relying on it

For every project: current stable release, supported Kubernetes versions
(cluster is v1.35.x), arm64 images, install manifests/helm chart and how to
disable optional parts, exact CRD field names (`kubectl explain` on the live
cluster — the Trainer v2 API in particular changed during its alpha).

## Done means

For each course built: every lesson passes the full test cycle in
`hack/COURSE_AUTHORING.md`; stop/start is clean; footprint measured and written
in STATUS.md; committed to `main` before starting the next. At the end this
file is deleted (or replaced by the overview README described above).

## Notes from building Course 1 (`kubeflow-trainer`)

Facts a later Kubeflow course can reuse (details in STATUS.md, decisions 53 onwards):

- **Component pattern for a CRD-heavy project without a helm repo:** `base/components/kubeflow-trainer` vendors the small
  non-CRD part of the upstream kustomize output (`controller.yaml`, image pinned by index digest) and downloads the
  four huge CRDs (2.5 MB) from the pinned tag at install time into `$KDRILL_STATE_DIR/cache/`, checking sha256
  (`crds.sha256`). Rendering used `kubectl kustomize` on a local clone of the tag, minus the bundled JobSet.
- Trainer v2.4.0 needs only a JobSet controller (built against **JobSet v0.13.0**, the version the repo's `jobset`
  component installs) and **no cert-manager**: the controller generates its own webhook certificate
  (`certManagement.enable: true`). Kubernetes >= 1.31.
- Webhooks are `failurePolicy: Fail`, scoped to `trainer.kubeflow.org` resources only. Kueue (v0.20.4, TrainJob
  integration on by default) also registers TrainJob webhooks, and it starts the TrainJob controller by itself
  when the CRD appears later: no Kueue restart or config change is needed whichever is installed first.
- The upstream stock runtimes pull multi-GB images and are not installed; lessons write their own runtimes.
- Engine stops components in `course.yaml` order, so `teardown.sh` removes TrainJobs/runtimes first.
- v2.4.0 ships an experimental `OptimizationJob` CRD (`trainer.kubeflow.org`: random-search hyperparameter
  optimization over TrainJob trials, behind the controller feature gates `OptimizationJob` and `TrainJobStatus`, which the
  `kubeflow-trainer` component does not enable). The CRD is installed, the feature is not taught; look at it again
  when designing the Katib course (docs: `docs/user-guides/optimizationjob.md` in the Trainer repository).
