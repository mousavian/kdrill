When the TrainJob has failed, find out why and what the JobSet did about it:

    kubectl get trainjob flaky -o jsonpath='{.status.conditions}'; echo
    kubectl get jobset flaky -o jsonpath='{.spec.failurePolicy}{" "}{.status.restarts}{"\n"}'
    kubectl get pods -o custom-columns=NAME:.metadata.name,EXIT:.status.containerStatuses[0].state.terminated.exitCode
---
Two separate things are missing. (1) A restart: the runtime's JobSet spec can have
`failurePolicy.maxRestarts` (put it under `spec.template.spec` of the ClusterTrainingRuntime; the TrainJob
snapshot is taken at creation, so recreate the TrainJob). (2) Something to resume from: a volume for
`CKPT_DIR`. The PVC `checkpoints` exists; the user adds volumes to a TrainJob with `spec.runtimePatches`
(`manager` must look like `domain/name`, e.g. `kdrill.dev/learner`) and sets `CKPT_DIR=/ckpt` in `spec.trainer.env`.
`kubectl explain trainjob.spec.runtimePatches --recursive | head -60`
---
See solution/:

    kubectl apply -f solution/runtime.yaml
    kubectl delete trainjob flaky
    kubectl apply -f solution/trainjob.yaml
