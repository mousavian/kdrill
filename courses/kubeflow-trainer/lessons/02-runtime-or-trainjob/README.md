# Who owns what - a team runtime and a small TrainJob

## Concept

Trainer splits a training run between two kinds of people, and two kinds of objects follow that split.

The **platform team** owns *runtimes*: which image, which launcher, which framework policy (`mlPolicy`), which
scheduling and failure behaviour. A `ClusterTrainingRuntime` is cluster-wide: write it once, every namespace
can use it. A `TrainingRuntime` is the same object scoped to one namespace, for a team that needs its own
defaults and does not want to edit (or cannot edit) the shared one. Their specs are identical.

The **person who trains** owns the *TrainJob*: how many nodes, which arguments, a few environment variables,
resources per node. The TrainJob only says *what* to run on top of a runtime; it should stay small.

Access control follows the same line. Give researchers permission to create TrainJobs in their namespace and
read-only access to ClusterTrainingRuntimes; give a team lead permission to manage TrainingRuntimes in the
team's namespace. Nobody can then change the platform's image by accident.

How a TrainJob picks a runtime is easy to get wrong. `spec.runtimeRef` has `apiGroup`, `kind` and `name`. If you
leave `kind` out it means **ClusterTrainingRuntime**. A namespaced runtime must be requested with
`kind: TrainingRuntime`, and it must live in the TrainJob's own namespace. The reference is checked when the
TrainJob is created and cannot be changed afterwards (`spec.runtimeRef` is immutable, and so is
`spec.trainer`).

## The situation

The platform's ClusterTrainingRuntime `tiny-gpt` exists (200 steps, seed 3). The research team wants 150 steps
and seed 7 as its own defaults, and has a TrainJob ready, `manifests/trainjob.yaml`, that names a runtime called
`team-tiny`. That runtime does not exist, and the TrainJob does not say which kind it is.

## Your task

1. Apply `manifests/trainjob.yaml` and read the answer.
2. Create the namespaced TrainingRuntime `team-tiny` in namespace `train`, based on the platform's runtime, with
   the team's defaults (`--steps 150 --seed 7`).
3. Fix the TrainJob `team-run` so it uses it, and let it complete.

`kdrill verify` checks that `team-tiny` is a TrainingRuntime in this namespace with the ancestor label on `node`;
that the TrainJob references it with `kind: TrainingRuntime`; that the TrainJob stays small (it sets no `image`,
`command` or `args`: those belong to the runtime) and passes `RUN_TEAM=research`; that the JobSet is owned by the
TrainJob; that the platform's ClusterTrainingRuntime `tiny-gpt` is unchanged; that the TrainJob completes
(about 20 s); and that the pod's log shows 150 steps and seed 7.

## Useful commands

    kubectl apply -f manifests/trainjob.yaml
    kubectl get clustertrainingruntimes,trainingruntimes
    kubectl get clustertrainingruntime tiny-gpt -o yaml
    kubectl explain trainjob.spec.runtimeRef
    kubectl auth can-i create clustertrainingruntimes --as=system:serviceaccount:train:default

## On a real cluster

Typical setups install the Trainer project's ClusterTrainingRuntimes for everyone (or write the platform's own)
and let teams add TrainingRuntimes where they need to deviate. A runtime is validated when it is created or
updated (the webhook checks, for example, that the replicated jobs and containers are consistent); the stock
runtimes carry the label `trainer.kubeflow.org/webhook-validation: disabled` so they can be applied before the
webhook is ready, which your own runtimes should not copy. Each TrainJob also keeps a snapshot of its runtime
in a ConfigMap (`<trainjob>-runtime-snapshot`, look at it), so editing a runtime later changes new TrainJobs
only, never the ones that already exist.

## Read more

- https://www.kubeflow.org/docs/components/trainer/operator-guides/runtime/
- https://www.kubeflow.org/docs/components/trainer/overview/
- https://www.kubeflow.org/docs/components/trainer/operator-guides/
