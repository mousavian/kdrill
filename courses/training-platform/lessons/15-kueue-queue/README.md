# Queue real training jobs with Kueue

## Concept

Kubernetes schedules pods; it does not queue jobs. Submit ten training Jobs
to a cluster that fits three, and the scheduler starts whatever pods fit,
leaves the rest Pending, and nobody decides which experiment should go first.
**Kueue** adds job-level queueing on top (the gpu-scheduling course showed it
on simulated GPUs; here it queues real runs):

- a **ClusterQueue** holds a quota per resource and **flavor** (a
  ResourceFlavor maps to a kind of node: GPU model, spot or on-demand);
- a **LocalQueue** in a namespace is where users submit; it points to a
  ClusterQueue;
- a Job joins the queue with the label `kueue.x-k8s.io/queue-name`. Kueue's
  webhook creates it **suspended** (`spec.suspend: true`, no pods) and
  creates a **Workload** object holding the Job's total requests;
- when the quota has room, Kueue **admits** the Workload (`QuotaReserved`,
  `Admitted`), unsuspends the Job, and the Job controller creates the pods.
  When the Job finishes (`Finished`), the quota is released and the next
  Workload is admitted.

The label has to be there when the Job is created: Kueue's webhook refuses
to add it to an existing Job ("field is immutable"). Jobs without the label are ignored by Kueue
(its default), which is how the earlier lessons ran.

## The situation

ResourceFlavor `default-flavor`, ClusterQueue `training-cq` (1500m CPU, 2Gi
memory: one 1-CPU training job at a time) and LocalQueue `training` exist.
Jobs `exp-a` and `exp-b` (500 steps each, 1 CPU each) were created without
the queue and run at the same time.

## Your task

- Both Jobs submitted to the LocalQueue `training`, each with a Kueue
  Workload, still requesting 1 CPU and training 500 steps.
- They never run at the same time: one is admitted, the other waits
  suspended, and is admitted after the first has finished. Both complete.
- Do not change `training-cq` or the LocalQueue.

## Useful commands

    kubectl get jobs,workloads
    kubectl get clusterqueue training-cq
    kubectl describe workload <name>
    kubectl get job exp-b -o jsonpath='{.spec.suspend}'

Each experiment takes about 45 seconds; verify after both have completed
(it tells you while they are still going).

## On a real cluster

Teams get one LocalQueue per namespace, ClusterQueues per team or project,
and **cohorts** to lend unused quota between teams (gpu-scheduling lesson
08). Flavors separate GPU models and spot from on-demand nodes, and Kueue can
trigger node autoscaling (ProvisioningRequest) for an admitted job. A
JobSet, a Ray job or a Kubeflow TrainJob is queued the same way.

## Read more

- https://kueue.sigs.k8s.io/docs/overview/
- https://kueue.sigs.k8s.io/docs/concepts/
- https://kueue.sigs.k8s.io/docs/tasks/run/jobs/
- https://kubernetes.io/docs/concepts/workloads/controllers/job/#suspending-a-job
