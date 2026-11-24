    kubectl apply -f manifests/urgent-eval.yaml
    kubectl get workloads
    kubectl describe workload <urgent-eval's workload> | tail
    kubectl get clusterqueue training-cq -o jsonpath='{.spec.preemption}'

Two things decide whether a waiting workload may evict a running one.
---
- The urgent Job needs a higher priority: label
  `kueue.x-k8s.io/priority-class: urgent` (WorkloadPriorityClasses `low` and
  `urgent` exist). Like the queue label, it counts at creation.
- The ClusterQueue must allow preemption by priority:
  `spec.preemption.withinClusterQueue: LowerPriority`. Do not change its quota.
---
    kubectl delete job urgent-eval --ignore-not-found
    kubectl apply -f solution/clusterqueue.yaml -f solution/urgent-eval.yaml
    kubectl get jobs,workloads -w
