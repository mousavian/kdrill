# Give the LLM its GPUs

## Concept

CPU and memory are built in. Anything else a node can offer — GPUs, FPGAs,
RDMA devices — is an **extended resource**: a name outside the `kubernetes.io`
domain, such as `nvidia.com/gpu`. On a real cluster a *device plugin* advertises
it in the node's `capacity` and `allocatable`; the scheduler then treats it like
any other countable resource.

The rules differ from CPU in important ways:

- **Whole integers only.** `nvidia.com/gpu: 0.5` is invalid. (Sharing needs
  time-slicing, MIG or DRA — later topics.)
- **Set it in `limits`.** For extended resources the request defaults to the
  limit, and if you specify both they must be equal. A request without a limit
  is rejected.
- **No overcommit.** Capacity is exact: a node with 4 GPUs can hand out at most
  4 in total across its pods. CPU requests can be less than limits; GPU cannot.
- **Exclusive by default.** A GPU given to one container is not shared with any
  other.
- **Per node.** A pod's GPUs all come from one node; two nodes with 1 free GPU
  each cannot serve a pod that needs 2.

Example:

    resources:
      limits:
        nvidia.com/gpu: 2

Because only GPU nodes advertise the resource, asking for it already steers the
pod to them. But GPU nodes are expensive, so they are usually **tainted**
(`nvidia.com/gpu=present:NoSchedule`) to keep CPU-only pods out; a GPU pod then
needs a **toleration** too. GPU feature discovery adds labels such as
`nvidia.com/gpu.product` which you can use with nodeSelector/affinity to pick a
GPU model.

The arithmetic matters: 2 GPU nodes × 4 GPUs = 8 GPUs, so with 2 GPUs per pod
at most 4 pods can run.

## The situation

Two CPU-only nodes (`cpu-1`, `cpu-2`) and two GPU nodes (`gpu-1`, `gpu-2`, 4
fake GPUs each, labelled `nvidia.com/gpu.present=true`, tainted
`nvidia.com/gpu=present:NoSchedule`). The `llm` Deployment (3 replicas) was
deployed with no GPU request: it's running on CPU nodes, where a model server
is useless.

## Your task

Make each `llm` pod get 2 GPUs and run on the GPU nodes.

Rules:
- The `llm` container has `limits: nvidia.com/gpu: 2` (a request, if you add
  one, must also be 2).
- The pod template tolerates the `nvidia.com/gpu` taint (toleration with key
  `nvidia.com/gpu`).
- All 3 replicas ready, all on nodes labelled `nvidia.com/gpu.present=true`.
- The GPU nodes keep their taint and their capacity of 4; CPU nodes get no GPU
  capacity. Don't add or edit nodes.

## Useful commands

    kubectl get nodes -L nvidia.com/gpu.present
    kubectl describe node gpu-1       # Taints, Capacity, Allocated resources
    kubectl get pods -o wide
    kubectl describe pod <pending-pod>
    kubectl explain pod.spec.containers.resources

When you think you're done: `kdrill verify`

**Bonus (not verified):** scale to 5 replicas
(`kubectl scale deploy llm --replicas=5`). Five pods need 10 GPUs but the
cluster has 8. Which pod goes Pending, and what does its event say? Compare with
`kubectl describe node gpu-1` ("Allocated resources"), then scale back to 3.

## Read more

- https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#extended-resources
- https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
