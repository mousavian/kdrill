# Priority: an urgent job preempts a long run, which resumes

## Concept

A queue in strict arrival order is not enough when jobs differ in urgency. A
week-long pretraining run should not block a release-blocking evaluation, but
it also should not be thrown away. Kueue combines three mechanisms:

- **WorkloadPriorityClass** (a Kueue object, independent of pod
  PriorityClasses): a Job gets one with the label
  `kueue.x-k8s.io/priority-class: <name>`. It orders the queue and decides who
  may preempt whom.
- **Preemption** in the ClusterQueue: `spec.preemption.withinClusterQueue`
  is `Never` by default. `LowerPriority` lets a pending workload that does
  not fit evict admitted workloads of lower priority in the same
  ClusterQueue (`reclaimWithinCohort` and `borrowWithinCohort` do the same
  across a cohort).
- **Eviction = suspension**: Kueue marks the victim's Workload `Evicted`
  (reason `Preempted`) and sets `suspend: true` on its Job. The Job controller
  deletes the pods (SIGTERM, grace period, SIGKILL). The Workload goes back to
  the queue and is admitted again when there is room; the Job controller then
  creates **new** pods.

Preemption is only cheap if the victim can resume: it must checkpoint on
SIGTERM (lesson 08) to storage that outlives the pod (lessons 05-06). This
lesson ties Part B and Part D together.

## The situation

`training-cq` (1500m CPU: one 1-CPU job at a time) has
`withinClusterQueue: Never`. WorkloadPriorityClasses `low` (100) and `urgent`
(1000) exist. Job `pretrain` (priority `low`, 6000 steps, about 6-8 minutes,
checkpoints every 100 steps on the PVC `checkpoints`) is admitted and
training. `manifests/urgent-eval.yaml` is a 200-step urgent job, not yet
submitted.

## Your task

- Make `training-cq` allow preemption by lower priority (keep its quota).
- Submit `urgent-eval` (through the queue `training`, priority class
  `urgent`, still 1 CPU) so that it preempts `pretrain` and completes.
- `pretrain` (unchanged) must be admitted again afterwards and continue from
  the checkpoint it wrote when it was preempted: `metrics.json` on the PVC
  shows an attempt that ended `preempted` at step N and the next one starting
  at step N.

## Useful commands

    kubectl get jobs,workloads,pods
    kubectl describe workload <name> | tail
    kubectl get clusterqueue training-cq -o yaml
    kubectl logs -f job/pretrain | grep -E "SIGTERM|stopping|resumed"

The urgent job takes about 20 s; verify once it has completed.

## On a real cluster

Preemption is common between training (low priority, checkpointed often)
and inference or interactive work (high priority). Cohorts let a team borrow
idle GPUs and get preempted when the owner reclaims them. Kueue can also
evict jobs whose pods do not become ready in time (`waitForPodsReady`), with
requeueing back-off settings that control how soon an evicted workload comes
back.

## Read more

- https://kueue.sigs.k8s.io/docs/concepts/workload_priority_class/
- https://kueue.sigs.k8s.io/docs/concepts/preemption/
- https://kueue.sigs.k8s.io/docs/concepts/cluster_queue/#preemption
- https://kueue.sigs.k8s.io/docs/concepts/workload/
