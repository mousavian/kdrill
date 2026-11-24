`kubectl describe pod` on a Pending critical pod: all nodes report
`Insufficient cpu`. The scheduler can only evict pods that are *less important*
than the pending one. Right now every pod has priority 0 — compare:
`kubectl get pods -o custom-columns=NAME:.metadata.name,PRIO:.spec.priority`.
---
Priority comes from a cluster-scoped **PriorityClass** (name + integer value;
higher wins), referenced by `spec.priorityClassName` in the pod spec. Create
one called `critical-priority`, then reference it from the critical pod template
(not from batch).
---
    kubectl create priorityclass critical-priority --value=1000 \
      --description="critical workloads"
    kubectl patch deploy critical --type merge \
      -p '{"spec":{"template":{"spec":{"priorityClassName":"critical-priority"}}}}'

(or `kubectl apply -f solution/priorityclass.yaml`, then edit the Deployment).
Give the cluster a few seconds to preempt and reschedule.
