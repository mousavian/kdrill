Work through it as a checklist, one question per lesson of this course:

    kubectl get trainjob,jobset,pods,workloads
    kubectl logs -l jobset.sigs.k8s.io/jobset-name=final-run --prefix | grep -i "rank\|connected" | head
    kubectl get clustertrainingruntime capstone-ddp -o yaml
    kubectl get clusterqueue team-cq -o jsonpath='{.spec.resourceGroups}'; echo

Do the nodes form one group (lesson 4)? Does anything restart a crash (6)? Is there a volume to resume from (6)?
Is the TrainJob in the queue (8)? How much does it ask per node, and how much does the queue have (3, 8)?
---
Runtime (the platform's side): `mlPolicy.torch: {}`, the command `torchrun /opt/ml-tiny/app/train.py`,
`failurePolicy.maxRestarts` in the JobSet spec. TrainJob (yours): the label `kueue.x-k8s.io/queue-name: team`,
`spec.trainer.resourcesPerNode` with a CPU request that fits the queue (2 CPU for 2 nodes: at most 1 per
node, 500m is plenty), `CKPT_DIR=/ckpt` and a PVC mount from `runtimePatches`. Keep the planted
fault: you cannot remove the crash, only survive it. The old TrainJob and its Workload must be deleted, and its pods
must be gone before you create the new one (same names and DNS names). `spec.trainer` and the runtime snapshot are fixed at creation.
---
See solution/:

    kubectl apply -f solution/runtime.yaml
    kubectl delete trainjob final-run
    kubectl wait --for=delete pod -l jobset.sigs.k8s.io/jobset-name=final-run --timeout=60s
    kubectl apply -f solution/trainjob.yaml
