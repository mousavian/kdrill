Look at the queues and what they use:

    kubectl get clusterqueue
    kubectl describe clusterqueue team-a-cq team-b-cq
    kubectl -n team-a describe workload

`exp-2` waits for quota (4 more GPUs needed) while team-b-cq's 4 GPUs are
unused. Separate ClusterQueues never share quota unless they belong to the
same **cohort**.
---
`spec.cohortName: research` on both ClusterQueues lets team-a borrow team-b's
unused quota. That alone doesn't give it back: by default
`spec.preemption.reclaimWithinCohort` is `Never`, so team-b would wait until
team-a's borrowed job finished. Set it to `Any`.
---
1. Patch both ClusterQueues:
   `kubectl patch clusterqueue team-a-cq --type merge -p '{"spec":{"cohortName":"research","preemption":{"reclaimWithinCohort":"Any"}}}'`
   (same for team-b-cq), or `kubectl apply -f solution/clusterqueues.yaml`.
2. Wait until `kubectl get workloads -A` shows both team-a workloads admitted.
3. `kubectl apply -f manifests/team-b-job.yaml` (from the lesson directory)
   and watch Kueue evict one team-a job to admit `eval-b`.
