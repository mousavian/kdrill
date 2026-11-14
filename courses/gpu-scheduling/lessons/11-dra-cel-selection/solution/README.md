# Solution

From the lesson directory:

    kubectl delete resourceclaimtemplate gpu-40g two-h100
    kubectl apply -f solution/claims.yaml
    kubectl apply -f solution/encoder-decoder.yaml
    kubectl rollout restart deploy llm trainer

- `gpu-40g`: selector
  `device.capacity["gpu.nvidia.com"].memory.compareTo(quantity("40Gi")) >= 0`
  rules out the 24Gi L4s.
- `two-h100`: `count: 2` and
  `device.attributes["gpu.nvidia.com"].productName == "NVIDIA H100 80GB HBM3"`.
  Both devices come from the same node, in one claim.
- `shared-l4`: a standalone ResourceClaim selecting an L4. `encoder` and
  `decoder` reference it with `resourceClaimName`, so the scheduler allocates
  it once (when the first of them is scheduled) and puts the other pod on the
  same node. `status.reservedFor` lists both pods.

Templates are immutable and a template-generated claim is made when its pod is
created, so changing the template means: delete, re-create, restart the pods.
The old pods' claims are deleted with the old pods.

Takeaways:
- CEL selectors on attributes and capacity replace "label the node and hope"
  with "describe the device you need".
- `count`/`allocationMode` ask for several devices; `constraints` (e.g.
  `matchAttribute`) keep them consistent.
- Template = exclusive per pod; ResourceClaim = shared by everyone who
  references it.
