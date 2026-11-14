# Solution

    kubectl apply -f solution/nodepool.yaml      # from the lesson directory

Within a few seconds Karpenter logs `found provisionable pod(s)`, then
`computed new nodeclaim(s) to fit pod(s)` and `created nodeclaim`. It added
up the four pods (4 CPU, 8 GiB) and asked for **one** node that fits them
all, listing every instance type that would do; the KWOK provider "launched"
the cheapest one. `c6i.xlarge` has 4 vCPUs, but after the system reserve
only 3.9 are allocatable, so four 1-CPU pods need the next size up:

    kubectl get nodeclaims
    NAME            TYPE          CAPACITY    ZONE         NODE   READY
    default-x7k2p   c6i.2xlarge   on-demand   us-west-2b   kwok-default-x7k2p-...   True

Record it (use the type you actually see):

    kubectl -n shop create configmap findings --from-literal=instance-type=c6i.2xlarge

What happened, step by step:
1. The scheduler marked the pods `Unschedulable` (the real node is tainted).
2. Karpenter batched the pending pods, filtered the catalogue with the
   NodePool's requirements (amd64, on-demand) and the pods' requests, and
   created a NodeClaim listing the instance types that fit.
3. The cloud provider created the instance (here: a KWOK Node object), the
   node registered and became Ready, and the scheduler bound the pods to it.
