Look at what the pod really got, and at the log's first lines. Which one is stronger, an environment
variable or a flag in the container's args?

    kubectl get pod -l jobset.sigs.k8s.io/jobset-name=tuned -o jsonpath='{.items[0].spec.containers[0].args}{"\n"}{.items[0].spec.containers[0].env}'
    kubectl logs -l jobset.sigs.k8s.io/jobset-name=tuned | head -5
---
The runtime puts `--steps 1200` on the command line; `train` lets a flag win over the STEPS variable.
`spec.trainer.args` **replaces** the runtime's args (it does not append), while `spec.trainer.env`
is **merged** with the runtime's environment and `resourcesPerNode` is merged over the runtime's
resources. `spec.trainer` is immutable: delete the TrainJob and create a new one.
`kubectl explain trainjob.spec.trainer`
---
See solution/trainjob.yaml:

    kubectl delete trainjob tuned
    kubectl apply -f solution/trainjob.yaml
