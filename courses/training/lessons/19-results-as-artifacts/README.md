# Results as artifacts: named runs, a model, and cleanup

## Concept

A training run produces more than a log line: checkpoints (to resume), a
final **model** (to evaluate and serve), and the facts needed to trust it
later (which data, which code, which hyperparameters, which loss). Treat them
as **artifacts** with a name and a version, written where they outlive the
Job:

- **One location per run.** Two runs sharing a checkpoint directory is the
  classic silent bug: the new run "resumes" from the old one, or overwrites
  it. Derive the path from the run's name, and the name from the Job: the
  downward API puts the pod's label `batch.kubernetes.io/job-name` into an env
  var, and later variables can use it as `$(RUN_NAME)`.
- **A model is not a checkpoint.** The final weights without optimizer state
  are smaller and are what an inference server loads; next to them, a small
  metadata file (run name, steps, loss, data hash, seed, configuration) makes
  the artifact reproducible and comparable. A model registry (MLflow, a
  bucket layout, an OCI image) builds on exactly this.
- **Retention.** Every checkpoint of a large model is gigabytes: keep the last
  few (plus milestones), not all of them. Finished Jobs and their pods pile up
  too: `ttlSecondsAfterFinished` lets Kubernetes delete them; the volumes and
  the artifacts on them stay.

The course's `train` reads `RUN_NAME`, keeps `CKPT_KEEP` checkpoints and
writes `MODEL_OUT/model.pt` and `MODEL_OUT/model.json` at the end.

## The situation

PVCs `checkpoints` and `models` exist. A previous run, `shakespeare-v1`, left
its checkpoints directly in the root of `checkpoints`. Job `shakespeare-v2`
(600 steps, seed 2, checkpoint every 50) uses `CKPT_DIR=/ckpt`, keeps every
checkpoint and writes no model. `manifests/sample.yaml` is a sampling Job
that expects the model in `/models/shakespeare-v2`.

## Your task

Job `shakespeare-v2` (still 600 steps, `CKPT_EVERY=50`):

- `RUN_NAME` from the Job's name label via the downward API;
  `CKPT_DIR=/ckpt/$(RUN_NAME)` and `MODEL_OUT=/models/$(RUN_NAME)`;
- keeps at most 2 checkpoints (`CKPT_KEEP`), and
  `ttlSecondsAfterFinished` between 300 and 86400;
- trains from step 0 to 600 into its own directory, and writes
  `models/shakespeare-v2/model.pt` and `model.json`;
- `shakespeare-v1`'s checkpoints stay where they are.

Then Job `sample` (from `manifests/sample.yaml`) completes, sampling from
`/models/shakespeare-v2/model.pt`.

## Useful commands

    kubectl logs job/shakespeare-v2 | head -n 4
    kubectl explain pod.spec.containers.env.valueFrom.fieldRef
    kubectl get job shakespeare-v2 -o jsonpath='{.spec.template.metadata.labels}'
    kubectl logs job/sample

Setup takes about 40 s (v1 trains first); the fixed v2 about 30 s.

## On a real cluster

Runs are usually named by the pipeline or tracker (an MLflow run ID, a
commit hash plus a date) and write to `s3://bucket/runs/<name>/`; lifecycle
rules on the bucket expire old checkpoints. Models are promoted from there
into a registry, often packaged as OCI images so a cluster can mount them
like any other image (the inference course mounts a model as an image
volume).

## Read more

- https://kubernetes.io/docs/tasks/inject-data-application/downward-api-volume-expose-pod-information/#capabilities-of-the-downward-api
- https://kubernetes.io/docs/tasks/inject-data-application/define-interdependent-environment-variables/
- https://kubernetes.io/docs/concepts/workloads/controllers/ttlafterfinished/
- https://mlflow.org/docs/latest/ml/model-registry/
