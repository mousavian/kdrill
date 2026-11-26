Apply the TrainJob and read the error. Who answers, and what does it say is missing?

    kubectl apply -f manifests/trainjob.yaml
    kubectl get clustertrainingruntimes
---
A runtime is a template of a JobSet. Take the pod template of `manifests/job.yaml` (image, command,
args, env, resources) and put it under `spec.template.spec.replicatedJobs[0].template.spec.template.spec`
of a ClusterTrainingRuntime named `tiny-gpt`. Two details matter: the replicated job must be
called `node` with a container called `node`, and its metadata needs the label
`trainer.kubeflow.org/trainjob-ancestor-step: trainer` (that is how the controller finds the
step the TrainJob's `spec.trainer` applies to). `kubectl explain clustertrainingruntime.spec.template.spec.replicatedJobs`
---
See solution/runtime.yaml:

    kubectl apply -f solution/runtime.yaml
    kubectl apply -f manifests/trainjob.yaml
