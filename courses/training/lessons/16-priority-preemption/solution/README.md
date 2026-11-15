# Solution

From the lesson directory:

    kubectl apply -f solution/clusterqueue.yaml        # preemption.withinClusterQueue: LowerPriority
    kubectl apply -f solution/urgent-eval.yaml         # priority-class: urgent
    kubectl get jobs,workloads -w

What happens:

1. `urgent-eval` is created suspended; its Workload has priority 1000 and does
   not fit next to `pretrain` (1 CPU each, 1500m of quota).
2. With `withinClusterQueue: LowerPriority`, Kueue may evict admitted
   workloads of lower priority to make room. It evicts `pretrain`'s Workload
   (condition `Evicted`, reason `Preempted`) and suspends the Job; the Job
   controller deletes the pod, which gets SIGTERM and writes a checkpoint.
3. `urgent-eval` is admitted and runs (about 20 s).
4. When it finishes, `pretrain` is admitted again; its new pod finds the
   checkpoint on the PVC and logs `resumed from ckpt-... at step N`.

With `Never` (the old setting), or without the priority label (priority 0,
lower than pretrain's), the urgent job simply waits for hours.
