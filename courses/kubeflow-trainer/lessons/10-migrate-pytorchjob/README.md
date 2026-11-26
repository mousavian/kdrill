# Migrating a PyTorchJob (Training Operator v1) to a TrainJob

## Concept

Before Trainer v2 there was the **Training Operator** (v1): one CRD per framework (`PyTorchJob`, `TFJob`,
`MPIJob`, `XGBoostJob`, ...), each with `*ReplicaSpecs` listing replica types and a pod template per type. For
PyTorch the replica types are `Master` and `Worker`:

```yaml
apiVersion: kubeflow.org/v1
kind: PyTorchJob
spec:
  runPolicy: {cleanPodPolicy: None, backoffLimit: 0}
  pytorchReplicaSpecs:
    Master: {replicas: 1, restartPolicy: Never, template: {spec: {containers: [{name: pytorch, image: ..., command: [...]}]}}}
    Worker: {replicas: 1, ...same shape...}
```

The operator created the pods and Services itself and injected `MASTER_ADDR`, `MASTER_PORT`, `WORLD_SIZE` and
`RANK` into each container. Everything lived in one object: the platform's choices (image, launcher, policies) and
the user's (arguments, scale) were mixed, and each framework had its own API and controller.

Trainer v2 splits and unifies this (lessons 1-4): a **runtime** holds the pod template, the launcher and the policy;
a **TrainJob** holds what changes per run; the pods come from JobSet instead of a framework-specific
controller; and the PyTorch policy injects the `PET_*` variables for `torchrun`. A migration therefore is
not a field-by-field conversion. For each field of the old manifest, decide whether it is the platform's (put it
in a runtime, or reuse one) or the run's (TrainJob), and then check what it becomes. The solution README has the
mapping table.

The Training Operator is not installed in this lab (its CRDs would not even be known to the cluster:
try `kubectl apply --dry-run=server -f manifests/pytorchjob.yaml`).

## The situation

`manifests/pytorchjob.yaml` is the team's v1 manifest: a Master and a Worker, 400 steps with seed 5 and batch
size 16 as arguments of `train`, `RUN_NAME=legacy-migration`, 500m CPU and 450Mi memory requested per replica
(memory limit 1Gi). The platform provides the runtime `tiny-ddp` (PyTorch policy, `torchrun` launcher).

## Your task

Create the TrainJob `tiny-pytorchjob` that runs the same training through `tiny-ddp`: 2 nodes, the same arguments,
the same `RUN_NAME`, the same resources. Do not change the runtime.

`kdrill verify` checks that the runtime is unchanged; that the TrainJob uses it with `numNodes: 2`, the old
arguments (`--steps 400 --seed 5 --batch-size 16`), `RUN_NAME=legacy-migration` in the pods and the requests and
limit of the old manifest on each; that the old `command` was **not** copied (the pods are started with
`torchrun`); that the controller injected the `PET_*` variables; that the Training Operator's CRD is not
installed; that the TrainJob completes (about 40 s); and that both nodes' logs show one DDP group (`rank 0/2`,
`rank 1/2`) with 400 steps, seed 5 and batch size 16.

## Useful commands

    cat manifests/pytorchjob.yaml
    kubectl get clustertrainingruntime tiny-ddp -o yaml
    kubectl explain trainjob.spec.trainer
    kubectl get trainjob,pods
    kubectl logs -l jobset.sigs.k8s.io/jobset-name=tiny-pytorchjob --prefix | grep -i "rank\|done"

## On a real cluster

Both APIs can run side by side while you migrate (the Training Operator and Trainer v2 use different CRDs; JobSet
and the Training Operator's controllers do not interfere). Kueue supports both (`kubeflow.org/pytorchjob` and
`trainer.kubeflow.org/trainjob` integrations). The official migration guide covers MPIJob too, where the move from
launcher/worker replica specs to an MPI runtime is bigger, and the Kubeflow SDK has one `TrainerClient` for all
frameworks. Elastic PyTorch (`elasticPolicy`) and the other framework CRDs have their own sections in the guide:
check what your version supports before planning a migration.

## Read more

- https://www.kubeflow.org/docs/components/trainer/operator-guides/migration/
- https://www.kubeflow.org/docs/components/trainer/user-guides/pytorch/
- https://www.kubeflow.org/docs/components/training/
