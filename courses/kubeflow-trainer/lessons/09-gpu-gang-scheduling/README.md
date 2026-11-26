# Gang scheduling multi-node TrainJobs on GPU nodes

## Concept

A multi-node TrainJob is an **all-or-nothing** workload: if the job needs 4 nodes, 3 running pods are worth
nothing, since they wait for the fourth (a collective operation such as an all-reduce cannot start without every
rank). The Kubernetes scheduler, though, schedules pods one at a time. When two such jobs compete for the same
GPUs, it can give each job part of what it needs: both hold GPUs, neither runs, and nothing ever frees them. This
is the *partial placement deadlock*, and what it looks like from outside is a set of `Running` pods that log
"waiting for workers" next to `Pending` pods whose events say `Insufficient nvidia.com/gpu`.

Ways to get gang behaviour for a TrainJob:

- **Kueue** (this lab, and what the Trainer docs recommend first): TrainJobs are created suspended, Kueue
  admits a whole TrainJob when its total requests fit the quota, and only then do pods exist.
- a **gang-scheduling plugin** in the scheduler (`podGroupPolicy` in the runtime: coscheduling, or Volcano),
  which keeps the pods of a PodGroup Pending until all of them can be placed; with Kueue you do not need it.

On GPU nodes the TrainJob also sets the GPU count per node: `resourcesPerNode` (or the runtime) puts
`nvidia.com/gpu` in the container's limits. The controller then leaves `PET_NPROC_PER_NODE=auto` (without GPUs it
turns the variable into the CPU request, lesson 4) and `torchrun` starts one process per GPU it finds on the node.

This is a **simulation lesson**: the cluster has two fake GPU nodes (KWOK) with 2 GPUs each, and no container
really starts; pods are `Running` because the simulated nodes say so. The real node carries a
`control-plane:NoSchedule` taint during the lesson, so nothing lands on it.

## The situation

Namespace `train`: runtime `gpu-ddp` (2 nodes, torchrun, 2 GPUs per node), a ClusterQueue `training-cq` with 4
GPUs and the LocalQueue `training`. TrainJobs `llama` and `mistral` each need 2 nodes x 2 GPUs = 4 GPUs and
were started at the same moment (outside the queue). Each got one node.

## Your task

Resubmit both TrainJobs through the queue `training` so that one runs on both nodes and the other waits as a
whole, holding no GPU. Do not change the queue, the runtime or the nodes.

`kdrill verify` checks that both TrainJobs ask for 2 nodes and carry the queue label (and the runtime is as it
was); that exactly one is admitted and runs with **2 pods on 2 different fake nodes**, each with 2 GPUs and
`PET_NPROC_PER_NODE=auto` injected; that the other is suspended with **no pods**; that no TrainJob is running
with only some of its nodes; and that the ClusterQueue and the nodes are unchanged.

## Useful commands

    kubectl get trainjobs,pods -o wide
    kubectl describe pod -l jobset.sigs.k8s.io/jobset-name=llama | grep -A8 Events
    kubectl get nodes -l type=kwok --show-labels
    kubectl get workloads
    kubectl describe workload WL | grep -A5 Conditions
    kubectl delete trainjob llama mistral

## On a real cluster

On GPU hardware the same TrainJob also needs a node selector or flavor for the GPU model, tolerations for GPU node
taints (Kueue's ResourceFlavor can inject both), and topology awareness for networking (`topologyRequest` in
Kueue, placement groups in the cloud). Add `waitForPodsReady` to Kueue's configuration to evict workloads whose
pods do not all start in time. The fake nodes here advertise `nvidia.com/gpu` capacity the way the NVIDIA device
plugin does; nothing is simulated about NCCL, so the lesson cannot show how a stuck rendezvous looks in logs.

## Read more

- https://kueue.sigs.k8s.io/docs/tasks/run/trainjobs/
- https://kueue.sigs.k8s.io/docs/concepts/
- https://www.kubeflow.org/docs/components/trainer/operator-guides/job-scheduling/overview/
- https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/
