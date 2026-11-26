# Fetch the data first - the dataset initializer

## Concept

Downloading a dataset or a base model is I/O work, not training. On a GPU cluster you do not want eight
expensive GPUs idle while one pod fetches 200 GB. Trainer models that with **initializers**: extra steps of the
TrainJob that run before the trainer, on cheap CPU pods, and leave their results on a shared volume.

The pieces, all in the runtime's JobSet template:

- a replicated job `dataset-initializer` (and/or `model-initializer`) with the ancestor label of the same name
  (`trainer.kubeflow.org/trainjob-ancestor-step: dataset-initializer`) and a container of that name;
- a volume called **`initializer`** mounted at `/workspace` (the dataset lands in `/workspace/dataset`, the model
  in `/workspace/model`), created per TrainJob from `volumeClaimPolicies` (a feature of JobSet: PVC templates
  owned by the JobSet);
- `dependsOn` on the trainer's job (`status: Complete` on the initializer), so the trainer's pods only appear
  when the data is there.

The TrainJob then says *what* to fetch: `spec.initializer.dataset.storageUri` (and `secretRef`, `env`). The
controller passes the URI to the initializer container as `STORAGE_URI`. The Trainer project ships initializer
images that understand `hf://` (Hugging Face) and `s3://`. The trainer container reads the result from the
shared volume. Admission enforces the convention: a TrainJob that asks for a dataset is refused if its runtime has
no initializer job with the right container and mount.

In this lab the initializer is the tiny image's `prepare` tool, unpacking the Shakespeare corpus that is already
inside the image (nothing is downloaded), so the step is real but cheap.

## The situation

The runtime `tiny-data` declares a dataset-initializer job and a trainer that reads `/workspace/dataset`, but it
has no shared volume. `manifests/trainjob.yaml` (TrainJob `withdata`, `initializer.dataset.storageUri:
file:///opt/ml-tiny/datasets/tinyshakespeare.txt.gz`) is refused.

## Your task

Fix the runtime `tiny-data` (a new TrainJob does not need to change) and run `withdata`.

`kdrill verify` checks that the runtime defines a volume claim template named `initializer` and mounts it in both
steps; that the TrainJob asks for the dataset by URI and is owned by the JobSet; that the initializer pod got
`STORAGE_URI` from the TrainJob and **finished before the trainer container started**; that the initializer
wrote `/workspace/dataset/input.txt`; that the TrainJob completes (about 40 s); and that the trainer's log reads
its data from `/workspace/dataset`.

## Useful commands

    kubectl apply -f manifests/trainjob.yaml
    kubectl get trainjob,jobset,jobs,pods,pvc
    kubectl logs -l jobset.sigs.k8s.io/replicatedjob-name=dataset-initializer
    kubectl get jobset withdata -o jsonpath='{.spec.replicatedJobs[*].dependsOn}'; echo
    kubectl explain clustertrainingruntime.spec.template.spec.volumeClaimPolicies

## On a real cluster

With ReadWriteOnce volumes the trainer pods must run where the initializer's volume is, which is fine for one
node and awkward for many; multi-node jobs use a ReadWriteMany volume or fetch from object storage in every
node. Trainer's `data-cache` feature (a Kubeflow-maintained cache cluster based on Apache Arrow) is the other
answer for large datasets. Credentials for private datasets go in `initializer.dataset.secretRef`.
The runtimes for LLM fine-tuning with TorchTune are built exactly this way: a dataset initializer, a model
initializer, then the trainer.

## Read more

- https://www.kubeflow.org/docs/components/trainer/operator-guides/runtime/
- https://www.kubeflow.org/docs/components/trainer/overview/
- https://www.kubeflow.org/docs/components/trainer/operator-guides/job-template/
- https://jobset.sigs.k8s.io/docs/concepts/
