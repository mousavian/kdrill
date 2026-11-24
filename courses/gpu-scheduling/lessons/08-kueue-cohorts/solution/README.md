# Solution

Step 1: put both ClusterQueues in a cohort and allow reclaiming
(from the lesson directory):

    kubectl apply -f solution/clusterqueues.yaml
    # same as, for each of team-a-cq and team-b-cq:
    # kubectl patch clusterqueue team-a-cq --type merge \
    #   -p '{"spec":{"cohortName":"research","preemption":{"reclaimWithinCohort":"Any"}}}'

    kubectl get workloads -A        # wait until both team-a workloads are admitted

team-a's `exp-2` was waiting for quota although 4 GPUs sat idle. In a cohort,
unused nominal quota of one queue can be borrowed by the others, so Kueue
admits `exp-2` on team-b's 4 GPUs (`kubectl describe clusterqueue team-a-cq`
shows the borrowed usage).

Step 2: team-b comes back:

    kubectl apply -f manifests/team-b-job.yaml

team-b is entitled to its 4 GPUs (its nominal quota). Because
`team-b-cq` has `reclaimWithinCohort: Any`, Kueue preempts the team-a
workload that is using borrowed quota: it evicts it (its pods are deleted and
the Job is suspended again) and requeues it. `eval-b` is admitted on the freed
quota. The evicted workload carries `Preempted` / `InCohortReclamation`
conditions (`kubectl -n team-a describe workload`).

Without `reclaimWithinCohort`, team-b would have waited until team-a's
borrowed job finished on its own (6 simulated hours).

Takeaways:
- Nominal quota = guaranteed share; a cohort turns idle shares into a pool.
- `borrowingLimit` caps how much a queue may borrow, `lendingLimit` how much
  of its quota it lends.
- Reclaiming preempts whole workloads; borrowed jobs must tolerate being
  stopped and resumed (checkpointing).
