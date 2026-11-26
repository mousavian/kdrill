# Solution

From the lesson directory:

    kubectl delete trainjob llama mistral
    kubectl apply -f solution/trainjobs.yaml
    kdrill verify

- The scheduler places pods one at a time and has no idea that `llama-node-0-0` and `llama-node-0-1` belong
  together. With 4 GPUs and two jobs that each need 4, the first pod of each job took a node and the second pod of
  each stayed `Pending` (`0/3 nodes are available: 2 Insufficient nvidia.com/gpu ...`): a deadlock in which both
  jobs hold GPUs and make no progress. Real training would be stuck at the rendezvous, waiting for the missing rank.
- With the queue label, Kueue creates each TrainJob **suspended** and a Workload for it, with the total need
  (2 nodes x 2 GPUs = 4 `nvidia.com/gpu`). It admits a Workload only if the whole amount fits the ClusterQueue's quota
  (4 GPUs): `llama` got it, and `mistral` waits suspended with no pods and no GPUs
  (`kubectl get workload` shows `couldn't assign flavors ... insufficient unused quota`). When `llama` finishes
  or is suspended, `mistral` is admitted.
- Because the pods request GPUs, the controller left `PET_NPROC_PER_NODE=auto`: `torchrun` starts one process per
  GPU on the node (2 here). Without GPUs it would have resolved the variable from the CPU request.
