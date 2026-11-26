# From a Job to a TrainJob

## Concept

A plain Kubernetes Job runs one pod template to completion. Distributed training needs more: several pods that
find each other, a shared start, one verdict for the group. **Kubeflow Trainer** (v2) packages that as two
custom resources:

- a **TrainingRuntime** (namespaced) or **ClusterTrainingRuntime** (cluster-wide): a *template*. Its
  `spec.template` is a JobSet spec (the container image, the launcher, the volumes), and its `mlPolicy` says
  how many nodes and which framework policy (PyTorch, MPI, ...) applies. The platform team writes these.
- a **TrainJob**: a *request*. It names a runtime in `spec.runtimeRef` and may override a few things in
  `spec.trainer` (image, command, args, env, number of nodes, resources per node). People who train write these.

The Trainer controller joins the two: it creates a **JobSet** named like the TrainJob, owned by it, and the
JobSet controller creates the Jobs and pods. The TrainJob's `status.conditions` (`Complete`, `Failed`,
`Suspended`) summarise the JobSet. You never create the JobSet yourself.

Two rules make the join work. The replicated job that runs the training carries the label
`trainer.kubeflow.org/trainjob-ancestor-step: trainer` (that is the step `spec.trainer` applies to), and its
container is called `node`. Admission checks the reference: a TrainJob whose runtime does not exist is
refused when you create it.

## The situation

The team has trained the tiny GPT with the Job `tiny-job` (see `manifests/job.yaml`; look at its log:
`kubectl logs job/tiny-job`). The platform now offers Kubeflow Trainer. `manifests/trainjob.yaml` is the TrainJob
`tiny`, which asks for a runtime called `tiny-gpt`. No such runtime exists, and no TrainJob exists yet.

## Your task

1. Apply `manifests/trainjob.yaml` and read what happens.
2. Create the ClusterTrainingRuntime `tiny-gpt` from the Job's pod template: the same image, command, args
   (200 steps, seed 3), environment and resources, with the replicated job `node`, its container `node` and the
   ancestor label.
3. Run the TrainJob `tiny` through it.

`kdrill verify` checks that the runtime exists and carries the ancestor label; that TrainJob `tiny` references it;
that the JobSet `tiny` is **owned by the TrainJob** (a hand-made JobSet is refused) and has one Job; that the pod
runs `kdrill.local/ml-tiny:0.1.0` with `train`; that the TrainJob completes (about 20 s; verify says what step
it is at while it runs); and that the log shows 200 steps with seed 3 and a final loss within 0.05 of the
Job's.

## Useful commands

    kubectl apply -f manifests/trainjob.yaml
    kubectl get clustertrainingruntimes,trainjobs
    kubectl get trainjob,jobset,jobs,pods
    kubectl get jobset tiny -o jsonpath='{.metadata.ownerReferences}'; echo
    kubectl explain clustertrainingruntime.spec.template.spec.replicatedJobs
    kubectl logs -l jobset.sigs.k8s.io/jobset-name=tiny

## On a real cluster

The Trainer project ships ready-made runtimes (`torch-distributed`, `deepspeed-distributed`, `jax-distributed`,
and so on) that you install once and reference by name; their images are multi-gigabyte CUDA images, so this lab
writes its own runtime around the tiny image instead. A TrainJob can also be created from Python with the
Kubeflow SDK (`TrainerClient().train(...)`), which only fills in the same fields. The older Training Operator
(PyTorchJob, TFJob, MPIJob) is still around: lesson 10 compares it. Trainer needs the JobSet controller;
this lab installs both.

## Read more

- https://www.kubeflow.org/docs/components/trainer/overview/
- https://www.kubeflow.org/docs/components/trainer/operator-guides/runtime/
- https://jobset.sigs.k8s.io/docs/overview/
- https://www.kubeflow.org/docs/components/trainer/operator-guides/
