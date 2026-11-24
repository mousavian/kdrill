# Solution

From the lesson directory:

    kubectl delete jobset ddp
    kubectl apply -f solution/jobset.yaml
    kdrill verify            # once past step 150: evicts a worker; verify again when the JobSet completes

- JobSet creates the headless Service itself (named after the JobSet, `ddp`)
  and sets every pod's subdomain to it. Pods are named
  `<jobset>-<replicatedJob>-<job index>-<pod index>`, so rank 0 is
  `ddp-workers-0-0` and its DNS name `ddp-workers-0-0.ddp`. The old
  `ddp-0.workers` belonged to the hand-made Service of lesson 11, which does
  not exist here: the workers waited for it until `DIST_TIMEOUT`, the child
  Job failed, and without a failure policy the JobSet failed.
- `failurePolicy.maxRestarts: 3`: when a child Job fails (the evicted worker
  fails the Job, `backoffLimit: 0`), JobSet deletes **all** its Jobs and
  creates them again, a group restart by policy, counted in
  `status.restarts`. The new workers rendezvous and resume from rank 0's
  checkpoint on the shared PVC.
- `successPolicy` (`All` of `workers`) is the default, written out: the
  JobSet is complete when every Job of the listed replicated jobs is.
