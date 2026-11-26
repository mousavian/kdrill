# Two nodes, one model - the PyTorch policy

## Concept

`numNodes` alone only makes more pods. Training them *together* needs a framework policy, set in the runtime's
`mlPolicy`: `torch` for PyTorch (also `mpi`, `jax`, `xgboost`, ...). With `mlPolicy.torch` the Trainer controller
wires every node of the TrainJob for `torchrun`, by injecting these environment variables into the trainer
container (they are reserved: a TrainJob cannot set them):

| Variable | Value |
|---|---|
| `PET_NNODES` | the number of nodes (`spec.trainer.numNodes`) |
| `PET_NPROC_PER_NODE` | processes per node: `spec.trainer.numProcPerNode` if set; else `auto` when the container requests GPUs (torchrun then starts one process per GPU); else the CPU request, rounded up |
| `PET_NODE_RANK` | the node's index in the Indexed Job (0, 1, ...) |
| `PET_MASTER_ADDR` | `<trainjob>-node-0-0.<trainjob>`: rank 0's pod, a DNS name from JobSet's headless Service |
| `PET_MASTER_PORT` | 29500 |

(`PET` stands for PyTorch Elastic Training.) `torchrun` reads them as its own options (`--nnodes`, `--node-rank`,
`--master-addr`, ...), so the runtime's command only has to be `torchrun script.py`, and the script finds
`RANK`, `WORLD_SIZE`, `MASTER_ADDR` and `MASTER_PORT` in its environment. PyTorch's DDP then keeps one copy of the
model per process and averages the gradients across processes on every step; on CPU the backend is `gloo`.

If the runtime has no policy, or the command does not go through `torchrun`, the pods simply do not know about
each other. Nothing fails: the TrainJob completes after training N independent models.

One more point from lesson 2: a TrainJob keeps a **snapshot** of its runtime, so correcting a runtime does not
repair TrainJobs that already exist; create them again. When you delete a multi-node TrainJob and create it again
under the same name, wait for the old pods to be gone first (`kubectl wait --for=delete pod -l
jobset.sigs.k8s.io/jobset-name=ddp`): the new pods get the same DNS names, and a new rank must not find an old pod.

## The situation

The platform's runtime `tiny-ddp` has `numNodes: 1`, no framework policy and runs `train` directly. The TrainJob
`ddp` (`manifests/trainjob.yaml`) asks for `numNodes: 2`; it has completed, and each pod trained on its own.

## Your task

Fix the runtime `tiny-ddp` and run the TrainJob again, so that the two nodes form one PyTorch DDP group:

- the PyTorch policy is on;
- the container launches `/opt/ml-tiny/app/train.py` through `torchrun`.

`kdrill verify` checks the runtime's policy; that TrainJob `ddp` asks for 2 nodes and its JobSet is owned by it
(one Indexed Job, 2 pods); that **the controller injected** `PET_NNODES=2`, the master address
`ddp-node-0-0.ddp` and port 29500, and a node rank taken from the completion index, in both pods (setting
`WORLD_SIZE` yourself in the TrainJob is the old, hand-made way and does not count); that the TrainJob completes
(about 30 s); and that both logs show `rank 0/2` and `rank 1/2` and `all 2 workers connected`.

## Useful commands

    kubectl get trainjob,jobset,jobs,pods -o wide
    kubectl get pods -l jobset.sigs.k8s.io/jobset-name=ddp -o jsonpath='{.items[0].spec.containers[0].env}'; echo
    kubectl logs -l jobset.sigs.k8s.io/jobset-name=ddp --prefix | grep -i "rank\|connected"
    kubectl get clustertrainingruntime tiny-ddp -o yaml
    kubectl get svc,cm

## On a real cluster

On GPU nodes `PET_NPROC_PER_NODE` stays `auto` (one process per GPU, from `resourcesPerNode`
`nvidia.com/gpu`) and the backend becomes `nccl`. The same TrainJob then runs on one 8-GPU node or on four
nodes by changing `numNodes` only. Rank 0's pod must be reachable by DNS from the others, which JobSet's
headless Service provides; if a worker cannot resolve it the run waits until the rendezvous times out (compare
the by-hand version in training-platform 11).

## Read more

- https://www.kubeflow.org/docs/components/trainer/user-guides/pytorch/
- https://www.kubeflow.org/docs/components/trainer/operator-guides/ml-policy/
- https://docs.pytorch.org/docs/stable/elastic/run.html
- https://docs.pytorch.org/tutorials/intermediate/ddp_tutorial.html
