# Solution

    kubectl apply -f solution/dra.yaml      # from the lesson directory

- DeviceClass `gpu.nvidia.com`: `device.driver == "gpu.nvidia.com"`.
- ResourceClaimTemplate `one-gpu`: one request, `exactly` 1 device of that class.

What happens next:
1. The resourceclaim controller sees each pending `vllm` pod referencing the
   template and creates a ResourceClaim per pod (`vllm-...-gpu-xxxxx`), owned
   by the pod.
2. The scheduler, for each pod, finds a node whose ResourceSlice has a free
   device matching the claim (class selector + request), writes the choice
   into `claim.status.allocation` (driver, pool = node, device = e.g.
   `l40s-2`) plus a node selector, reserves it for the pod
   (`status.reservedFor`), and binds the pod.
3. On a real node the driver's kubelet plugin would now prepare that GPU for
   the container.

Inspect it:

    kubectl get resourceclaims
    kubectl get resourceclaim <name> -o yaml

When a pod is deleted, its claim is deleted too and the device is free again.

Takeaways:
- Devices are described (attributes, capacity) in ResourceSlices, requested in
  claims, and allocated by the scheduler, so the allocation is visible in the API.
- DeviceClass = admin/driver-defined filter; claims = user requests.
- Template → one claim per pod; a standalone ResourceClaim → shared by every
  pod that references it (next lesson).
