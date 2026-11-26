Try the TrainJob and read the error, then list what exists in the namespace and in the cluster:

    kubectl apply -f manifests/trainjob.yaml
    kubectl get clustertrainingruntimes
    kubectl get trainingruntimes

Which kind does `runtimeRef` mean when you leave `kind` out?
---
Create a **TrainingRuntime** (namespaced: `kind: TrainingRuntime`, `metadata.namespace` is the TrainJob's)
named `team-tiny`. Its spec has the same shape as the platform's ClusterTrainingRuntime
(`kubectl get clustertrainingruntime tiny-gpt -o yaml`): copy it, then set the team's defaults
(150 steps, seed 7). In the TrainJob, `runtimeRef.kind: TrainingRuntime` is how you point at a
namespaced runtime.
---
See solution/team-runtime.yaml and solution/trainjob.yaml:

    kubectl apply -f solution/team-runtime.yaml
    kubectl apply -f solution/trainjob.yaml
