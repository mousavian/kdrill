# Let critical work preempt batch work

## Concept

When a cluster is full, which pod wins? By default none: pods are equal, so a
new pod waits as `Pending` however important it is. **Pod priority** changes
that.

A **PriorityClass** is a cluster-scoped object mapping a name to an integer:

    apiVersion: scheduling.k8s.io/v1
    kind: PriorityClass
    metadata:
      name: critical-priority
    value: 1000              # higher = more important
    globalDefault: false     # true would apply it to every pod without a class
    description: ...

A pod opts in with `spec.priorityClassName: critical-priority`; the admission
controller copies the number into `spec.priority`. Pods without a class get
priority 0 (or the class marked `globalDefault`, if any).

Priority does two things:
1. **Queue order** — higher-priority pending pods are scheduled first.
2. **Preemption** — if a pending pod fits nowhere, the scheduler looks for a
   node where it *would* fit after removing lower-priority pods. If it finds
   one, it evicts just enough victims (gracefully), and nominates that node for
   the pending pod (`status.nominatedNodeName`).

A class can set `preemptionPolicy: Never` to keep the queue ordering but never
evict anything. Kubernetes' own `system-cluster-critical` and
`system-node-critical` classes (values around 2 billion) are reserved for
system components; use your own for applications.

Preempted pods are not special-cased: their Deployment simply creates
replacements, which then wait for room. Preemption is a blunt tool — in real
clusters pair it with PodDisruptionBudgets awareness and sensible priority tiers.

## The situation

Two nodes with 4 CPUs each. The `batch` Deployment (4 replicas × 2 CPU) uses
every CPU. The new `critical` Deployment (2 replicas × 2 CPU) is Pending.
Capacity is fixed, and batch work may be interrupted.

## Your task

Make `critical` run by preempting `batch` pods.

Rules:
- Create a PriorityClass named `critical-priority` with a value above 0. It must
  not be `globalDefault` and must keep the default preemption policy.
- Set it on the `critical` pod template (`spec.template.spec.priorityClassName`).
- Don't touch `batch`: it keeps `replicas: 4`, its 2 CPU requests, and gets no
  priority class. The end state is 2 batch pods Running and 2 Pending.
- Don't add or resize nodes.

## Useful commands

    kubectl get pods -o wide
    kubectl get pods -o custom-columns=NAME:.metadata.name,PRIO:.spec.priority,NODE:.spec.nodeName
    kubectl describe pod <pending-pod>
    kubectl get events --sort-by=.lastTimestamp
    kubectl explain priorityclass

When you think you're done: `kdrill verify`

## Read more

- https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/
- https://kubernetes.io/docs/concepts/scheduling-eviction/
