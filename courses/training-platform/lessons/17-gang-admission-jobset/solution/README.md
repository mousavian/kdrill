# Solution

From the lesson directory:

    kubectl delete jobset ddp-a ddp-b
    kubectl apply -f solution/jobsets.yaml
    kubectl get jobsets,workloads,pods -w

- The queue label goes on the **JobSet** (not on its Job templates). Kueue's
  JobSet integration suspends the JobSet at creation and creates one Workload
  for it, with one pod set per replicated job: here `workers`, count 2,
  2 x 750m CPU = 1500m.
- `training-cq` has 1500m: the first Workload is admitted whole, JobSet
  creates its Job and both pods start together; the second Workload is not
  admitted, its JobSet stays suspended and **no pod of it exists**. Nothing
  can hold half a gang.
- When the first JobSet completes, its quota is released and the second is
  admitted, again all at once.

Labelling the Job template inside the JobSet instead queues each child Job
on its own: no "whole set" guarantee once a JobSet has several replicated
jobs, and in this lab the suspended child Job's pods were created and deleted
in a loop while Kueue and the JobSet controller disagreed.
