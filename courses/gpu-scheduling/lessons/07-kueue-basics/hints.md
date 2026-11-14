Start from the Jobs and their Workloads:

    kubectl get jobs,workloads
    kubectl describe workload <name>

The Jobs are suspended (`spec.suspend: true`) and the Workloads say the
LocalQueue `ml-team` doesn't exist. Kueue needs three objects: a
ResourceFlavor, a ClusterQueue that holds the quota, and a LocalQueue in the
namespace that points to it.
---
Field reference: `kubectl explain clusterqueue.spec.resourceGroups --api-version=kueue.x-k8s.io/v1beta2`.
Two traps: `coveredResources` must list every resource the pods request (cpu,
memory and nvidia.com/gpu), and a ClusterQueue without `namespaceSelector`
accepts **no** namespace (use `namespaceSelector: {}`).
---
    kubectl apply -f solution/kueue.yaml      # from the lesson directory

ResourceFlavor `a100` (nodeLabels nvidia.com/gpu.product=NVIDIA-A100-SXM4-80GB),
ClusterQueue `ml-cq` (namespaceSelector {}, cpu 64 / memory 512Gi / GPU 8 in
flavor a100), LocalQueue `ml-team` → `ml-cq`. Two Jobs (4 GPUs each) fit in
8 GPUs; the third waits.
