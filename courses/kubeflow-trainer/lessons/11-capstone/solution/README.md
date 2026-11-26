# Solution

From the lesson directory:

    kubectl apply -f solution/runtime.yaml
    kubectl delete trainjob final-run
    kubectl wait --for=delete pod -l jobset.sigs.k8s.io/jobset-name=final-run --timeout=60s
    kubectl apply -f solution/trainjob.yaml
    kdrill verify            # about 1.5 minutes: admission, run, crash of rank 1 at 300, restart, resume, finish

What was wrong, in the order a careful reader finds it:

1. **No group.** The runtime had no `mlPolicy.torch` and ran `train` directly: two independent trainings
   (lesson 4). Fix in the runtime: the Torch policy and `torchrun /opt/ml-tiny/app/train.py`.
2. **No restart.** `backoffLimit: 0` and no `failurePolicy`: the first crash would fail the TrainJob
   (lesson 6). Fix in the runtime: `failurePolicy.maxRestarts: 3`.
3. **No checkpoints.** Nothing to resume from. Fix in the TrainJob: `CKPT_DIR=/ckpt` and the PVC `checkpoints`
   mounted through `runtimePatches`. With it, the crash at step 300 (planted) happens once, the restarted
   group resumes from the newest checkpoint (step 250 or 300), and the "failed once" marker on the volume
   stops the crash from repeating.
4. **Not queued, and too big for the quota.** The TrainJob had no queue label (lesson 8), and the runtime's
   "generous" `requests.cpu: 2` per node made 4 CPUs for 2 nodes against a quota of 2: even
   queued, the Workload would never be admitted. The TrainJob's `resourcesPerNode` (lesson 3) asks for 500m per node.
   The quota was not touched.
5. The TrainJob had to be created again: `spec.trainer`, `runtimeRef` and the runtime snapshot are fixed
   at creation (lessons 2-4).

- Why the `kubectl wait`: the old TrainJob's pods stay `Terminating` for a few seconds, and the new TrainJob's pods
  have **the same names and DNS names** (`final-run-node-0-0.final-run`). A new rank that resolves the name too early can reach an old pod
  and fail when that pod dies. The lab's runtime sets `terminationGracePeriodSeconds: 3` to keep the window short;
  waiting for the old pods to disappear closes it. (On a real cluster, use a new name for every run.)
