# Borrow idle GPUs across teams, reclaim them on demand

## Concept

A static quota per team wastes GPUs: when team B is idle, its share sits
unused while team A's jobs queue. Kueue solves this with **cohorts**.
ClusterQueues that set the same `spec.cohortName` form a pool:

- Each queue's `nominalQuota` is its guaranteed share.
- A queue whose own quota is used up can **borrow** unused quota of other
  queues in the cohort, up to its `borrowingLimit` (unlimited if unset). A
  lender can keep part of its share out of the pool with `lendingLimit`.
- When the lender needs its quota back, `spec.preemption` decides what happens:
  - `reclaimWithinCohort: Never` (default): wait until borrowers finish.
  - `LowerPriority`: preempt borrowing workloads of lower priority.
  - `Any`: preempt borrowing workloads regardless of priority.
  - (`withinClusterQueue` controls preemption among a queue's own workloads,
    and `borrowWithinCohort` whether a borrower may preempt to borrow.)

Kueue preemption works on **whole workloads**: it evicts the job (deletes all
its pods and suspends it again) and puts it back in the queue with a
`Preempted` condition (reason `InCohortReclamation`). When quota frees up
again it is readmitted and restarts, which is why training jobs should
checkpoint.

A **Cohort** object can also be created explicitly to build hierarchies and
give the cohort itself quota; for two teams sharing, `cohortName` is enough.

## The situation

One 8×H100 node. Setup created flavor `h100`, ClusterQueues `team-a-cq` and
`team-b-cq` (4 GPUs nominal each, no cohort) and LocalQueues `team-a` and
`team-b`. team-a submitted `exp-1` and `exp-2` (4 GPUs each). `exp-1` runs;
`exp-2` waits for quota, while team-b's 4 GPUs are idle.

## Your task

1. Put both ClusterQueues in cohort `research`, so that `exp-2` gets admitted
   by borrowing team-b's unused quota.
2. Allow team-b to reclaim: `team-b-cq` gets
   `spec.preemption.reclaimWithinCohort: Any` (set it on team-a-cq too).
3. *After* `exp-2` is running, submit team-b's job:
   `kubectl apply -f manifests/team-b-job.yaml` (from the lesson directory).

End state: `eval-b` admitted and Running; team-a has one Job running and one
back in the queue (no pods), and that requeued Job shows it was preempted by
in-cohort reclamation, which is proof that it had borrowed.

Rules: don't change the quotas (4 GPUs nominal each, no lendingLimit
changes); don't delete team-a's Jobs; don't change the node.

## Useful commands

    kubectl get workloads -A
    kubectl describe clusterqueue team-a-cq          # Borrowed / usage
    kubectl -n team-a describe workload              # conditions, events
    kubectl get pods -A -o wide -l batch.kubernetes.io/job-name
    kubectl explain clusterqueue.spec.preemption --api-version=kueue.x-k8s.io/v1beta2

When you think you're done: `kdrill verify`

## Read more

- https://kueue.sigs.k8s.io/docs/concepts/cluster_queue/#cohort
- https://kueue.sigs.k8s.io/docs/concepts/preemption/
- https://kueue.sigs.k8s.io/docs/concepts/cohort/
