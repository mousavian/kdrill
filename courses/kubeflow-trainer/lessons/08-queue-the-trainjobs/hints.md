See what Kueue knows about these jobs (nothing), and what it offers:

    kubectl get trainjobs,pods
    kubectl get workloads
    kubectl get localqueue,clusterqueue
---
Kueue manages a TrainJob that carries the label `kueue.x-k8s.io/queue-name: <LocalQueue>`. It cannot adopt
a job that is already running: delete the TrainJobs, wait until their pods are gone (the new pods get the same DNS names) and create them again
with the label (Kueue's webhook
creates them suspended and admits them when the quota allows). `kubectl get workloads` then shows one
Workload per TrainJob.
---
See solution/trainjobs.yaml:

    kubectl delete trainjob exp-a exp-b
    kubectl wait --for=delete pod -l 'jobset.sigs.k8s.io/jobset-name in (exp-a,exp-b)' --timeout=60s
    kubectl apply -f solution/trainjobs.yaml
