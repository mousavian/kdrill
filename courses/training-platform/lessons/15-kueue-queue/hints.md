    kubectl get clusterqueue training-cq -o yaml
    kubectl get localqueue -n train
    kubectl get workloads

There are no Workloads: Kueue is not managing the Jobs. What tells Kueue a Job belongs to a queue?
---
Add the label `kueue.x-k8s.io/queue-name: training` to both Jobs' metadata. It
only counts at creation time, so delete the Jobs and create them again. Do not
change the queues or the Jobs' requests.
---
    kubectl delete job exp-a exp-b
    kubectl apply -f solution/jobs.yaml
    kubectl get jobs,workloads -w
