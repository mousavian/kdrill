# Solution

    kubectl apply -f solution/nodepool.yaml      # from the lesson directory

The new requirements (arm64, category `m`, `instance-cpu Gt 3`, on-demand)
leave `m7g.xlarge` ... `m7g.8xlarge`. Karpenter batches the 7 pending pods
(6 × 500m + 12 CPU = 15 CPU, 30 GiB), finds that they fit on one node, and
asks for "m7g.4xlarge or m7g.8xlarge"; the cheapest, `m7g.4xlarge`
(15.9 allocatable vCPUs), is launched:

    kubectl get nodeclaims
    NAME            TYPE          CAPACITY    ZONE         ...
    general-8h2kd   m7g.4xlarge   on-demand   us-west-2c   ...

Things to notice:
- Before the fix, Karpenter's event on the pods said exactly that:
  `Failed to schedule pod, nodepool requirements filtered out all available instance types`.
- One node for everything was the cheapest fit. If `worker` arrived later it
  would get its own node, and consolidation (lesson 8) could repack them.
- `Gt` takes a string value (`"3"`): label values are always strings.
