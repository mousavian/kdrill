Compare what the two pods know about each other. Which variables reach them, and what does each worker
log say about its rank?

    kubectl get pods -l jobset.sigs.k8s.io/jobset-name=ddp -o jsonpath='{.items[0].spec.containers[0].env}'; echo
    kubectl logs -l jobset.sigs.k8s.io/jobset-name=ddp --prefix | grep -i "rank\|connected" | head
---
The controller injects `PET_NNODES`, `PET_NODE_RANK`, `PET_MASTER_ADDR`... only when the runtime has a framework
policy: `spec.mlPolicy.torch`. `torchrun` reads exactly those `PET_*` variables, but the container runs `train`
directly, which does not. Change the runtime (`kubectl edit clustertrainingruntime tiny-ddp`) and launch the
script with `torchrun` (script: `/opt/ml-tiny/app/train.py`). A TrainJob keeps a snapshot of its runtime, so
the old TrainJob has to go: delete it, wait until its pods are gone (same names, same DNS names), and apply
`manifests/trainjob.yaml` again.
---
See solution/runtime.yaml:

    kubectl apply -f solution/runtime.yaml
    kubectl delete trainjob ddp
    kubectl wait --for=delete pod -l jobset.sigs.k8s.io/jobset-name=ddp --timeout=60s
    kubectl apply -f manifests/trainjob.yaml
