# Solution

From the lesson directory:

    kubectl delete job train
    kubectl apply -f solution/job.yaml

What was wrong:

1. **OOMKilled.** `kubectl describe pod` shows `Last State: Terminated,
   Reason: OOMKilled, Exit Code: 137`. Activation memory grows with the batch
   size: about 400 MB at 32 sequences, 450 MB at 64, 550 MB at 128 and 1.1 GB
   at 512, so batch 512 can never fit in 768 MiB, and every retry dies the same
   way until `backoffLimit` is used up. Lower `BATCH_SIZE` (here 64); raising
   the limit was not allowed by the budget.
2. **No requests.** With only a memory limit, the request defaults to the limit
   (768Mi) but CPU has neither, so the pod is scheduled as if it needed no CPU.
   Requests are what the scheduler reserves; limits are what the kernel enforces.
3. **Threads.** PyTorch starts one thread per core it can *see*, and a
   container sees every core of the node, not its CPU limit. With a CPU limit
   of 2 on an 8-core node, 8 threads share 2 cores' worth of CFS quota and are
   throttled all the time. `OMP_NUM_THREADS` from `resourceFieldRef:
   limits.cpu` keeps the two in step (it rounds up to whole cores).

The Job's pod template is immutable, so it is deleted and created again.
