    kubectl get jobsets,workloads
    kubectl get clusterqueue training-cq -o jsonpath='{.status}'

No Workloads: Kueue does not know about the JobSets. Which object should carry the queue label?
---
Put `kueue.x-k8s.io/queue-name: training` in the JobSet's own `metadata.labels`
and create the JobSets again (the label counts at creation). Keep two workers
per JobSet and their requests: the quota is sized for one whole JobSet.
---
    kubectl delete jobset ddp-a ddp-b
    kubectl apply -f solution/jobsets.yaml
