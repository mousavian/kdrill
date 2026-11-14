# Solution

`critical` is Pending with `Insufficient cpu` because `batch` holds all 8 CPUs.
Both Deployments run at priority 0, so the scheduler has no grounds for evicting
one pod to place another.

Create a PriorityClass and give it to the `critical` pod template:

    kubectl apply -f solution/priorityclass.yaml      # from the lesson directory
    # same thing: kubectl create priorityclass critical-priority --value=1000
    kubectl patch deploy critical --type merge \
      -p '{"spec":{"template":{"spec":{"priorityClassName":"critical-priority"}}}}'

The new `critical` pods are Pending but now carry priority 1000. The scheduler
looks for a node where evicting lower-priority pods would make the pod fit,
picks victims (here one 2-CPU `batch` pod per node), deletes them and nominates
the node for the pending pod (see `NOMINATED NODE` and the `Preempted` events).
The `batch` Deployment then recreates its two missing pods, which stay Pending:
the cluster is full again, but now with the important work first.

Takeaways:
- Priority only matters when the cluster is full; otherwise everything schedules.
- Don't make a class `globalDefault` casually: it changes every pod without one.
- `preemptionPolicy: Never` gives a class queue-jumping order without evicting anyone.
- Preemption deletes pods gracefully; workloads must tolerate being evicted.
