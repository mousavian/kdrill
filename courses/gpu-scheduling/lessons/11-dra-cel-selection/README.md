# Pick devices with CEL, claim several, share one

## Concept

DRA requests can say *which* devices they want. Each request in a claim
(`spec.devices.requests[].exactly`) has:

- `deviceClassName`: the base filter (here `gpu.nvidia.com`).
- `selectors`: extra CEL expressions. All must be true for a device to
  qualify. CEL sees the device's attributes and capacity, qualified by the
  driver's domain:

      device.attributes["gpu.nvidia.com"].productName == "NVIDIA H100 80GB HBM3"
      device.attributes["gpu.nvidia.com"].architecture == "Hopper"
      device.capacity["gpu.nvidia.com"].memory.compareTo(quantity("40Gi")) >= 0

  Capacities are quantities, so compare them with `compareTo(quantity(...))`.
  Version attributes (`driverVersion`, `cudaComputeCapability`) use
  `semver(...)` helpers.
- `count` (default 1) with `allocationMode: ExactCount`, or
  `allocationMode: All` for every matching device on the node. All devices of
  one claim come from the **same node**.
- At claim level, `constraints` such as `matchAttribute` can require that all
  allocated devices agree on an attribute (e.g. same `productName`).

**Sharing** is decided by how a pod references a claim:

- `resourceClaimTemplateName` → a new claim per pod: exclusive devices.
- `resourceClaimName` → an existing, standalone **ResourceClaim**. Every pod
  that references it uses the *same* allocated device(s), and all of them run
  on that device's node. The claim's `status.reservedFor` lists the pods. Use
  it when containers or pods must share a GPU on purpose (e.g. passing tensors
  in GPU memory).

Allocation happens once, when the first pod using the claim is scheduled.
Claims made from templates are created with the pod and never change.
ResourceClaimTemplates are immutable; to change one, delete and re-create it,
then recreate the pods.

## The situation

`mixed-1` has 2 × L4 (24Gi) and 2 × L40S (48Gi); `h100-1` has 4 × H100
(80Gi), all published as DRA devices of driver `gpu.nvidia.com` (DeviceClass
`gpu.nvidia.com` exists). Four Deployments run, each with 1 replica, but
their claims ask for "any GPU":

- `llm` (template `gpu-40g`) needs at least 40Gi of GPU memory.
- `trainer` (template `two-h100`) needs two H100s.
- `encoder` and `decoder` (template `any-gpu`) must share one L4.

## Your task

- `gpu-40g` gets a CEL selector on memory capacity (≥ 40Gi); `llm` runs on an
  L40S or H100.
- `two-h100` requests `count: 2` with a CEL selector on `productName` (or
  `architecture`); `trainer` runs with exactly two H100s from its one claim.
- Create ResourceClaim `shared-l4` (namespace `drill`) for one device with
  `productName == "NVIDIA L4"`. `encoder` and `decoder` reference it with
  `resourceClaimName: shared-l4`, and a Running pod of each is listed in its
  `status.reservedFor`.

Rules: keep 1 replica per Deployment; don't change the nodes, ResourceSlices
or the DeviceClass.

## Useful commands

    kubectl get resourceslices -o yaml | grep -E 'name:|productName|memory' 
    kubectl get resourceclaims
    kubectl get resourceclaim <name> -o jsonpath='{.status.allocation.devices.results}'
    kubectl get pod <pod> -o jsonpath='{.status.resourceClaimStatuses}'
    kubectl rollout restart deploy llm trainer

When you think you're done: `kdrill verify`

## On a real cluster

The NVIDIA DRA driver publishes more attributes (e.g. `cudaDriverVersion`,
MIG devices, NVLink/clique information for multi-node NVLink) and names
devices `gpu-0`, `gpu-1`, ... Here device names encode the model only so that
allocations are easy to read. Your selectors look the same. Sharing a claim between pods also needs the driver to support it (the
NVIDIA driver can share a GPU between containers and pods, optionally with
time-slicing or MPS configured in the claim's `config`). Here allocation is
real and nothing is prepared on the (fake) node.

## Read more

- https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/
- https://kubernetes.io/docs/reference/using-api/cel/
- https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/dra-gpus.html
