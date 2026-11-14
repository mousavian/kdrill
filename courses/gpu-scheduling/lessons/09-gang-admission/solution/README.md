# Solution

From the lesson directory:

    kubectl delete job llama-ft mistral-ft
    kubectl apply -f solution/jobs.yaml      # same jobs + kueue.x-k8s.io/queue-name: training

Kueue's webhook creates both Jobs suspended and makes one Workload each (4
pods × 1 GPU = 4 GPUs). `training-cq` has 4 GPUs of quota, so Kueue admits
the first workload as a whole, injects the flavor's node selector and
unsuspends it. All 4 workers are created and fit, because the quota equals the
real capacity. The second workload stays queued, its Job stays suspended,
and it holds nothing. When the first job completes, the second is admitted.

Why relabel instead of editing: Kueue only manages a Job if the queue label is
there when the Job is created (its webhook suspends it at that point). A Job
that is already running can't get the label added.

Takeaways:
- kube-scheduler is pod-by-pod; multi-pod jobs need admission or scheduling
  that treats the gang as a unit.
- Kueue's quota check is all-or-nothing per workload. Keep quota ≤ real
  capacity, or enable waitForPodsReady to evict and requeue jobs that only
  partly start.
