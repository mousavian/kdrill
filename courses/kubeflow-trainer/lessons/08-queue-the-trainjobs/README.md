# Queue TrainJobs with Kueue

## Concept

Without a queue, every TrainJob starts as soon as its pods fit. With a busy cluster that means half-started jobs
that block each other, no priorities and no fairness. **Kueue** (a Kubernetes SIG project, installed in this lab,
see also gpu-scheduling lessons 7-9 and training-platform 15-17) adds admission control in front of workloads.
It supports TrainJob out of the box (the integration `trainer.kubeflow.org/trainjob`).

The model: a **ClusterQueue** owns quota (here CPU and memory in one flavor), a **LocalQueue** in the team's
namespace points at it, and a workload joins the queue with the label `kueue.x-k8s.io/queue-name: <LocalQueue>`.
For a TrainJob Kueue's webhook creates it **suspended**, Kueue creates a **Workload** that represents it (its
`podSets` are the TrainJob's replicated jobs with `count` = number of nodes), and when the ClusterQueue can
cover the Workload's total requests it **admits** it by setting `spec.suspend: false`. This is the suspend
mechanism from the previous lesson, used by a controller. Until then the TrainJob has no pods at all: a
multi-node job is admitted as a unit, never half.

Two details matter. Kueue works from resource **requests** summed over all nodes (`numNodes` x
`resourcesPerNode`, taken from the runtime if the TrainJob does not override them): get the requests wrong and
the quota is wrong. And queue membership is decided at creation: a TrainJob that is already running is not
picked up when you add the label later (the label may only change while the job is suspended), so the usual fix is
to submit it again.

## The situation

The runtime `tiny-ddp` (2 nodes, torchrun) and Kueue objects exist: ClusterQueue `training-cq` with 1 CPU and
2Gi of memory, and the LocalQueue `training` in this namespace. TrainJobs `exp-a` and `exp-b` (2 nodes, each node
requests 500m CPU) were submitted without a queue and are running at the same time.

## Your task

Submit both through the LocalQueue `training`, so that they run one after the other: while one runs, the other is
suspended with no pods. Do not touch the queues.

`kdrill verify` checks that the ClusterQueue is unchanged (quota and all); that `exp-a` and `exp-b` still ask for
2 nodes with their original arguments and carry the queue label; that each has a Kueue Workload owned by the
TrainJob whose podSet counts 2 nodes; that they are **never admitted at the same time**; that both complete (about
1-2 minutes; verify reports where they are); and that the second was admitted only after the first finished.

## Useful commands

    kubectl get trainjobs,pods
    kubectl get workloads
    kubectl get workload WL -o yaml        # podSets, conditions: QuotaReserved, Admitted, Finished
    kubectl get clusterqueue training-cq -o jsonpath='{.status.flavorsUsage}'; echo
    kubectl delete trainjob exp-a exp-b

## On a real cluster

Quota in a ClusterQueue is usually expressed in GPUs (`nvidia.com/gpu`) per flavor (GPU model), shared across
teams in a cohort with borrowing and preemption (gpu-scheduling 8). Kueue can also gate the TrainJob on
`waitForPodsReady`, priorities (`WorkloadPriorityClass`), and fair sharing, and can dispatch to other clusters
(MultiKueue) by setting the TrainJob's `managedBy` field. When Kueue admits a TrainJob it records the chosen
flavor's node selectors and tolerations in the TrainJob's `runtimePatches` (look at the entry whose manager
is `kueue.x-k8s.io/manager`).

## Read more

- https://kueue.sigs.k8s.io/docs/tasks/run/trainjobs/
- https://kueue.sigs.k8s.io/docs/concepts/workload/
- https://kueue.sigs.k8s.io/docs/concepts/cluster_queue/
- https://www.kubeflow.org/docs/components/trainer/operator-guides/job-scheduling/overview/
