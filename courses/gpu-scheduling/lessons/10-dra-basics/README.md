# Dynamic Resource Allocation (DRA) fundamentals

## Concept

`nvidia.com/gpu: 1` is just a count. The scheduler can't ask for "a GPU with
at least 40 GB", can't share one GPU between two pods on purpose, and only
learns which GPU a pod got after the kubelet's device plugin picks one.
**Dynamic Resource Allocation** (`resource.k8s.io/v1`, GA since Kubernetes
1.34) replaces counting with describing and claiming devices:

- **ResourceSlice** (cluster-scoped): published by a DRA driver for each node.
  It lists the node's devices with typed **attributes** (`productName`,
  `architecture`, `driverVersion`, ...) and **capacity** (`memory: 48Gi`).
- **DeviceClass** (cluster-scoped): a named filter over devices, usually
  installed by the driver, e.g. "devices of driver `gpu.nvidia.com`",
  written as a CEL expression: `device.driver == "gpu.nvidia.com"`.
- **ResourceClaim** (namespaced): a request such as "exactly 1 device of
  class `gpu.nvidia.com`". Its `status.allocation` records which device was
  picked; `status.reservedFor` lists the pods using it.
- **ResourceClaimTemplate**: a pod that references a template gets its *own*
  claim, created by the resourceclaim controller and deleted with the pod.
  This is the usual "one GPU per replica" pattern.

A pod lists claims in `spec.resourceClaims` and each container opts in with
`resources.claims: [{name: ...}]`. **The scheduler does the allocation**: for
each candidate node it checks whether the node's ResourceSlices have free
devices matching the claim, picks them, and writes the result into the claim
before binding the pod. The kubelet then asks the driver to prepare the
device (set up `/dev` nodes, CDI specs) for the container.

## The situation

Two DRA-managed nodes with 4 L40S each. They advertise **no**
`nvidia.com/gpu`; their GPUs are listed in ResourceSlices for driver
`gpu.nvidia.com` (`kubectl get resourceslices`). The `vllm` Deployment (3
replicas) references a ResourceClaimTemplate `one-gpu` that doesn't exist,
and there is no DeviceClass either. All pods are Pending.

## Your task

- Create DeviceClass `gpu.nvidia.com` that selects the devices of driver
  `gpu.nvidia.com` (a CEL selector on `device.driver`).
- Create ResourceClaimTemplate `one-gpu` (namespace `drill`) with one request
  for exactly 1 device of class `gpu.nvidia.com`.
- All 3 `vllm` replicas Running, each with its own claim allocated to one GPU
  from the pool of the node the pod runs on, and no GPU allocated twice.

Rules: don't change the `vllm` Deployment (it keeps 3 replicas, its claim
reference, and no `nvidia.com/gpu`); don't change nodes or ResourceSlices.

## Useful commands

    kubectl get resourceslices -o yaml | less
    kubectl explain deviceclass.spec.selectors.cel
    kubectl explain resourceclaimtemplate.spec.spec.devices.requests.exactly
    kubectl get resourceclaims
    kubectl get resourceclaim <name> -o jsonpath='{.status.allocation.devices.results}'
    kubectl describe pod -l app=vllm

When you think you're done: `kdrill verify`

## On a real cluster

The NVIDIA DRA driver (`k8s-dra-driver-gpu`) runs a kubelet plugin on every GPU
node. It publishes the ResourceSlices, installs DeviceClasses such as
`gpu.nvidia.com` and `mig.nvidia.com`, and prepares allocated devices for
containers. KWOK nodes have no kubelet, so here the slices are written by the
lesson and nothing prepares the device. **Allocation, though, is the real
kube-scheduler.** Attribute names follow the NVIDIA driver, but check your
driver's slices for the exact set.

## Read more

- https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/
- https://kubernetes.io/docs/tasks/configure-pod-container/assign-resources/allocate-devices-dra/
- https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/dra-intro-install.html
