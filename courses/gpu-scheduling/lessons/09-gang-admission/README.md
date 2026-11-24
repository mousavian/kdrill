# All-or-nothing admission for distributed training

## Concept

A distributed training job (PyTorch DDP/FSDP, DeepSpeed, JAX) is a **gang**:
N workers that start together, connect to each other (NCCL), and synchronise
every step. With 3 of 4 workers running, the job does nothing at all. The 3
running workers sit in their rendezvous, holding their GPUs, waiting for the
4th.

kube-scheduler places pods **one at a time**. It has no idea that four pods
belong together. When two such jobs arrive together on a cluster that fits
only one, the scheduler can give each job half its workers:

    llama-ft    ██ ██ ░░ ░░      2 running, 2 Pending
    mistral-ft  ██ ██ ░░ ░░      2 running, 2 Pending   → all GPUs busy, zero progress

Neither job can finish, so neither frees its GPUs: a **deadlock**. On a
real cluster this keeps expensive GPUs busy while no work gets done.

The fix is **gang admission**: decide per job, not per pod. Kueue does this
by design. A job's Workload contains *all* its pods' requests, and Kueue
admits it only when the quota fits the whole thing; otherwise the whole job
stays suspended with zero pods. If the ClusterQueue's quota matches what the
nodes can really provide, an admitted job's pods all fit, and two jobs can no
longer block each other.

When quota and physical capacity can differ (fragmented nodes, autoscaling,
node failures), Kueue's **waitForPodsReady** setting adds a timeout: if an
admitted job's pods aren't all running within it, Kueue evicts the whole job
and requeues it, instead of letting it hold a partial allocation. It's a
controller-wide setting in Kueue's configuration (off in this lab).

Other gang-aware options: JobSet and LeaderWorkerSet (admitted by Kueue as one
unit), and scheduler plugins such as coscheduling (PodGroup). Kubernetes v1.35
also added an alpha, off-by-default Workload API for gang scheduling in
kube-scheduler itself.

## The situation

Two nodes with 2 L40S GPUs each (4 GPUs). Two Indexed Jobs, `llama-ft` and
`mistral-ft`, each need 4 workers × 1 GPU at the same time. They were
submitted directly (no queue) and are deadlocked at 2/4 workers each. Setup
also created a Kueue flavor `l40s`, ClusterQueue `training-cq` (4 GPUs, the
real capacity) and LocalQueue `training`.

## Your task

Resubmit both Jobs through the LocalQueue `training`, so that:

- one Job is admitted and runs all 4 workers;
- the other waits in the queue: suspended, with no pods and no GPUs.

`kueue.x-k8s.io/queue-name` has to be set when the Job is created (Kueue
won't take over a Job that is already running). Delete the Jobs and create
them again with the label: the original manifests are in `manifests/jobs.yaml`.

Rules: both Jobs must exist with the label `kueue.x-k8s.io/queue-name:
training`, and keep `parallelism: 4`, `completions: 4` and 1 GPU per worker.
Don't change the ClusterQueue or the nodes.

## Useful commands

    kubectl get jobs,pods -o wide
    kubectl get workloads
    kubectl describe workload <name>
    kubectl delete job llama-ft mistral-ft
    kubectl label --dry-run=client -f manifests/jobs.yaml kueue.x-k8s.io/queue-name=training -o yaml

When you think you're done: `kdrill verify`

## On a real cluster

Real workers would also fail their NCCL rendezvous after a timeout and the
Job would retry or fail. Here the fake pods just wait, which shows the GPU
waste clearly. The second job's pods would start as soon as the first job
finished (6 simulated hours here).

## Read more

- https://kueue.sigs.k8s.io/docs/tasks/run/jobs/
- https://kueue.sigs.k8s.io/docs/tasks/manage/setup_wait_for_pods_ready/
- https://kubernetes.io/docs/concepts/workloads/controllers/job/#completion-mode
- https://jobset.sigs.k8s.io/docs/overview/
