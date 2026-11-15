# Solution

From the lesson directory:

    kubectl delete job exp-a exp-b
    kubectl apply -f solution/jobs.yaml
    kubectl get jobs,workloads -w

- The label `kueue.x-k8s.io/queue-name: training` must be on the Job when it
  is **created**: Kueue's webhook then sets `spec.suspend: true` and creates a
  Workload for the Job (its pod count times its requests). Adding the label
  to an existing Job is rejected by the webhook (the field is immutable),
  hence delete and re-create.
- `training-cq` has 1500m CPU of quota and each Job requests 1 CPU: Kueue
  admits the first Workload (reserves the quota, unsuspends the Job; the Job
  controller creates the pod) and leaves the second pending. The second Job
  has no pods at all while it waits.
- When the first Job finishes, its Workload is `Finished`, the quota is
  released and Kueue admits the second one by itself.

The quota is an accounting rule, independent of what the node could hold:
Kueue never looks at nodes unless you use topology or provisioning features.
Keep quotas at or below real capacity.
