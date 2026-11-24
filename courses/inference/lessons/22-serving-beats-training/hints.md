    kubectl get pods -o wide
    kubectl describe pod -l app=chat | grep -B2 -A3 Events:      # the Pending one: why can it not be scheduled?
    kubectl get priorityclass

The default scheduler only evicts pods that have a LOWER priority than the pending pod. Right now everything has
priority 0, so nothing can be preempted.
---
Create two PriorityClasses (cluster-scoped; label them `kdrill.dev/lesson=inference.22-serving-beats-training` so cleanup
removes them): `serving` (value 100000) and `training` (value 1000), and set `priorityClassName` in
the pod templates of `chat` and `finetune`. The Deployments roll; the Pending chat pod then preempts one finetune pod.
---
    kubectl apply -f solution/priority.yaml      # from the lesson directory
    kubectl get pods -o wide
