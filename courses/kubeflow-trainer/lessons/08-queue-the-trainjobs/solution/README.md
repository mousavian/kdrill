# Solution

From the lesson directory:

    kubectl delete trainjob exp-a exp-b
    kubectl wait --for=delete pod -l 'jobset.sigs.k8s.io/jobset-name in (exp-a,exp-b)' --timeout=60s
    kubectl apply -f solution/trainjobs.yaml
    kdrill verify            # about 1-2 minutes: one run after the other

- The label `kueue.x-k8s.io/queue-name: training` is all a TrainJob needs: Kueue's webhook sets `spec.suspend: true`
  when the TrainJob is created, Kueue creates a **Workload** for it (`kubectl get workloads`) and, when the
  ClusterQueue has quota, admits it by flipping `suspend` to false. Only then does the Trainer controller
  resume the JobSet and the pods appear.
- A TrainJob's resource needs are the pod templates summed over the nodes: 2 nodes x (500m CPU, 450Mi) = 1 CPU, so
  the Workload of one TrainJob uses the whole CPU quota of the ClusterQueue (nominalQuota 1) and the second
  one waits, suspended, with no pods. When the first finishes, its quota is released and the second is
  admitted.
- A running job cannot be adopted: Kueue is not told about TrainJobs that are already unsuspended
  without a queue label, so they were deleted and created again. The quota was never changed.

- Why the `kubectl wait`: the old TrainJob's pods stay `Terminating` for a few seconds, and the new TrainJob's pods
  have **the same names and DNS names** (`exp-a-node-0-0.exp-a`). A new rank that resolves the name too early can reach an old pod
  and fail when that pod dies. The lab's runtime sets `terminationGracePeriodSeconds: 3` to keep the window short;
  waiting for the old pods to disappear closes it. (On a real cluster, use a new name for every run.)
