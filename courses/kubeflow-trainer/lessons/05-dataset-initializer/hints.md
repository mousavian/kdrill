Apply the TrainJob and read the whole error: what does the Trainer webhook want to find in the runtime's
dataset-initializer container?

    kubectl apply -f manifests/trainjob.yaml
---
The initializer and the trainer run in different pods, so the data must travel on a volume. Trainer's
convention: a volume called `initializer`, mounted at `/workspace` in the initializer container (the webhook
insists) and in the trainer container (which reads `/workspace/dataset`). The PVC is created per TrainJob by
JobSet from `spec.template.spec.volumeClaimPolicies` of the runtime:
`kubectl explain clustertrainingruntime.spec.template.spec.volumeClaimPolicies`
---
See solution/runtime.yaml:

    kubectl apply -f solution/runtime.yaml
    kubectl apply -f manifests/trainjob.yaml
