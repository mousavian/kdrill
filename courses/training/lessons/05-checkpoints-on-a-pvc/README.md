# Checkpoints on a volume, and a Job that uses them

## Concept

A **checkpoint** is everything needed to continue or use a training run:
the model weights, the optimizer state (Adam keeps two extra numbers per
weight), the step counter and the random-number state. Training scripts
write one every N steps; where they write it decides what survives.

An `emptyDir` volume is created with a pod and **deleted with it**, whether the
pod succeeded, failed or was deleted. It survives container restarts inside
the same pod, nothing more. Checkpoints in an emptyDir are lost exactly when
you need them. A **PersistentVolumeClaim** is independent of pods: one Job
writes to it, and later pods (a retry, an evaluation, a sampling or serving
Job) mount the same claim and read the files.

Kubernetes does not order Jobs. Two Jobs created together run together, so a
consumer started next to its producer reads a half-finished (or empty) volume.
Either wait for the producer (`kubectl wait --for=condition=Complete`), or let
a workflow engine run the steps in order (Argo Workflows, Kubeflow Pipelines,
Airflow); the consumer should also check what it reads (here the sampler
prints the step of the checkpoint it loaded).

The course's `train` writes `ckpt-NNNNNN.pt` every `CKPT_EVERY` steps into
`CKPT_DIR`, keeps the newest three, updates a `latest` pointer and
`metrics.json` (status, step, loss). `sample --model DIR` loads the newest
checkpoint in DIR and generates text.

## The situation

PVC `checkpoints` exists. Job `train` (600 steps, checkpoint every 100) writes
to `/ckpt`, an emptyDir. Job `sample` mounts the PVC at `/ckpt` and was
created at the same time.

## Your task

- Job `train` writes its checkpoints (`CKPT_DIR`) to the PVC `checkpoints`,
  still every 100 steps or more often, and completes 600 steps. Afterwards the
  volume holds `metrics.json` with status `done` at step 600 and several
  checkpoints, the newest from step 600.
- Job `sample` (mounting the PVC) completes and prints text sampled from the
  step-600 checkpoint.

## Useful commands

    kubectl logs job/train | grep checkpoint
    kubectl logs job/sample
    kubectl get pvc checkpoints
    kubectl wait job/train --for=condition=Complete --timeout=180s

Training takes about 30 seconds, sampling a few.

## On a real cluster

Checkpoints of large models are tens to hundreds of gigabytes, written by
many GPUs at once. They go to a shared filesystem or object storage (lesson
09), often asynchronously and sharded per rank (PyTorch Distributed
Checkpoint). A `local-path` PVC is tied to one node: a pod scheduled elsewhere
cannot mount it, which is why multi-node clusters use network storage.

## Read more

- https://kubernetes.io/docs/concepts/storage/volumes/#emptydir
- https://kubernetes.io/docs/concepts/storage/persistent-volumes/
- https://docs.pytorch.org/tutorials/beginner/saving_loading_models.html
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_wait/
