    kubectl get pods
    kubectl describe pod -l batch.kubernetes.io/job-completion-index=1 | tail -n 5
    kubectl get pvc checkpoints

Why is one worker Pending? Read the scheduler's event.
---
`ReadWriteOncePod` allows a single pod. Two workers need a mode that allows
several pods: `ReadWriteOnce` (all on one node, fine in this one-node lab) or
`ReadWriteMany` (any node; needs a network filesystem). A PVC's access modes
cannot be edited: delete the Job, then the PVC, and create both again.
---
    kubectl delete job ddp
    kubectl delete pvc checkpoints
    kubectl apply -f solution/pvc.yaml -f solution/ddp.yaml
