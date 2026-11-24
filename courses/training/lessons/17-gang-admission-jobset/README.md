# Gang admission: a JobSet is queued whole

## Concept

A distributed run is a **gang**: its workers are useless one by one. The
gpu-scheduling course (lesson 09) showed the deadlock that per-pod scheduling
causes: two 4-worker jobs on 4 GPUs each get 2 workers and wait forever. Gang
admission avoids it by deciding per job, not per pod.

Kueue does that by design. For a JobSet submitted to a queue (label
`kueue.x-k8s.io/queue-name` on the **JobSet**), Kueue's webhook suspends it at
creation and creates **one Workload** for the whole set, with one *pod set*
per replicated job (`count` = its pods, with their requests). The Workload is
admitted only when the quota fits **all** pod sets; until then the JobSet stays
suspended and has no Jobs and no pods. When admitted, JobSet creates every
Job, and all workers start together.

Quota is an accounting rule: if it matches what the nodes can really run, an
admitted gang always fits. When quota and capacity can differ (fragmented
nodes, autoscaling), Kueue's `waitForPodsReady` evicts an admitted gang whose
pods do not all start in time, and requeues it, instead of letting it hold
part of the cluster.

## The situation

ResourceFlavor `default-flavor`, ClusterQueue `training-cq` (1500m CPU: one
2-worker run at 2 x 750m) and LocalQueue `training` exist. JobSets `ddp-a`
and `ddp-b` (each one Indexed Job of 2 DDP workers, 600 steps) were created
without the queue and run side by side.

## Your task

- Both JobSets submitted to the LocalQueue `training`, each with **one**
  Kueue Workload covering both of its workers; still 2 workers of 750m CPU
  each. Don't change the queues.
- Never a JobSet with only some of its workers: one is admitted with both
  workers, the other waits with none, and both complete one after the other.

## Useful commands

    kubectl get jobsets,workloads,pods
    kubectl get workload <name> -o jsonpath='{.spec.podSets[*].count}'
    kubectl describe clusterqueue training-cq | tail
    kubectl explain jobset.metadata.labels

Each JobSet trains for about 40 seconds; verify after both have completed.

## On a real cluster

Gangs of hundreds of GPUs are admitted the same way, often with topology-aware
scheduling (Kueue's TopologyAwareScheduling places the whole gang in one rack
or NVLink domain) and with ProvisioningRequests that ask the autoscaler for all
nodes at once. Kubernetes v1.35 also has an alpha Workload API for gang
scheduling in kube-scheduler itself.

## Read more

- https://kueue.sigs.k8s.io/docs/tasks/run/jobsets/
- https://kueue.sigs.k8s.io/docs/concepts/workload/
- https://kueue.sigs.k8s.io/docs/tasks/manage/setup_wait_for_pods_ready/
- https://jobset.sigs.k8s.io/docs/overview/
