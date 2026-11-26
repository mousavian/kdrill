# Solution

From the lesson directory:

    kubectl apply -f solution/trainjob.yaml
    kdrill verify            # about 40 s for the run

| PyTorchJob (v1) | TrainJob (v2) |
|---|---|
| `Master.replicas: 1` + `Worker.replicas: 1` | `spec.trainer.numNodes: 2` (node 0 plays the master) |
| container `pytorch`, image | the runtime's container `node`, image |
| `command: [train, ...options]` | the runtime's `command: [torchrun, script]`; the options become `spec.trainer.args` |
| `env` | `spec.trainer.env` (merged with the runtime's) |
| `resources` of each replica | `spec.trainer.resourcesPerNode` |
| the operator injects `MASTER_ADDR`, `MASTER_PORT`, `WORLD_SIZE`, `RANK` | the Torch policy injects `PET_NNODES`, `PET_NODE_RANK`, `PET_MASTER_ADDR`, `PET_MASTER_PORT`, ...; `torchrun` turns them into the four variables the script expects |
| `runPolicy.backoffLimit`, `cleanPodPolicy`, `activeDeadlineSeconds`, `ttlSecondsAfterFinished` | the runtime's JobSet (`failurePolicy`, `ttlSecondsAfterFinished`) and `spec.activeDeadlineSeconds` of the TrainJob |
| `status.replicaStatuses`, conditions `Created/Running/Succeeded/Failed` | `status.jobsStatus`, conditions `Complete/Failed/Suspended` |

If the old `command` (`train ...`) were copied into `spec.trainer.command`, the container would not go through
`torchrun`: the pods would train separately, as in lesson 4.
