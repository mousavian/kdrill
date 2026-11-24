# Solution

The Pending pod's events say `Insufficient cpu`: each pod requests 3 CPUs and
each node only has 4, so a node fits exactly one pod. Two nodes → two pods.

Lower the request so two pods fit on one node (2 × request ≤ 4), while staying
at or above 1 CPU:

    kubectl set resources deploy web --requests=cpu=1500m

The Deployment replaces the pods (it uses `strategy: Recreate` here, because a
rolling update can deadlock when the cluster has no headroom: the old 3-CPU
pods keep the nodes full, so the new pods can never fit); the scheduler now fits two on one node and
one on the other.

Takeaway: scheduling is arithmetic on *requests* vs *allocatable*. Over-sized
requests waste capacity just as surely as missing nodes do.
