# Solution

From the lesson directory:

    kubectl delete jobset capstone
    kubectl apply -f solution/capstone.yaml
    kubectl get jobset,workloads,pods -w        # crash at step 300, restart, resume, done at 900
    kubectl apply -f solution/sample.yaml       # after the JobSet is Completed
    kubectl logs -f job/sample

The four faults:

1. **No queue label** on the JobSet: it ran outside Kueue, next to whatever
   else was running. `kueue.x-k8s.io/queue-name: training` on the JobSet makes
   it one Workload, admitted whole (lesson 17).
2. **No failure policy**: worker 1's crash failed its Job (`backoffLimit: 0`)
   and with it the JobSet. `failurePolicy.maxRestarts` restarts the whole set
   instead (lesson 14).
3. **Checkpoints in an emptyDir**: each restart began at step 0, and since the
   "crash once" marker lived next to the checkpoints, the crash came back
   every time. On the shared PVC `checkpoints`, the restarted workers resume
   from step 300 and the fault does not repeat (lessons 05, 12).
4. **No `MODEL_OUT`**: the run left no model for the sampling Job
   (lesson 19).

Not faults: the crash itself (it stands for a flaky node or NIC), `backoffLimit: 0`
in the child Job (the JobSet decides), and `MASTER_ADDR` (already right).
