# Solution

From the lesson directory:

    kubectl delete job ddp
    kubectl apply -f solution/ddp.yaml
    kdrill verify            # evicts worker 1 once the run is past step 150; verify again when it completes

What happens on the eviction:

1. Worker 1 gets the `DisruptionTarget` condition and SIGTERM. It tells its
   peer (the workers all-reduce a stop flag every step), rank 0 writes a
   checkpoint, worker 1 exits 143 and rank 0 exits **75** ("the group
   stopped").
2. Both pods have failed. With `backoffLimit: 0` and no policy, the first
   failure ended the Job. The two `Ignore` rules match both pods (the evicted
   one by its condition, the stopped peer by exit code 75), so neither counts
   (`status.failed` stays 0) and the Job creates a new pod for each index.
3. The new pods rendezvous again (same DNS names, `ddp-0.workers`), every rank
   loads rank 0's checkpoint from the shared volume, and training continues
   from the step where the eviction happened.

A real crash (any other exit code) still fails the Job at once. The group
restart here is a by-product of every worker exiting when one goes; JobSet
(next lesson) makes "restart all workers" an explicit policy.
