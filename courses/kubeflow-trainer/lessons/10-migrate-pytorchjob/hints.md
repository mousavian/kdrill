Read the legacy manifest as a list of things to place somewhere in v2: how many nodes? what runs? what
is the same for every run? Try applying it to see what the cluster says:

    kubectl apply --dry-run=server -f manifests/pytorchjob.yaml
    kubectl get clustertrainingruntime tiny-ddp -o yaml
---
Master + Worker with one replica each is `numNodes: 2` (node 0 is the master). The image, the launcher and the
framework policy are the runtime's; the old `command` was `train ...` with the options as arguments: only
the arguments (`args`) move to the TrainJob, the runtime already launches `torchrun`. `env` and
`resources` move to `spec.trainer.env` and `spec.trainer.resourcesPerNode`. The operator's own variables (MASTER_ADDR,
WORLD_SIZE, RANK) are no longer yours: the PyTorch policy injects PET_*.
---
See solution/trainjob.yaml:

    kubectl apply -f solution/trainjob.yaml
