List the GPU labels side by side:

    kubectl get nodes -L nvidia.com/gpu.product,nvidia.com/gpu.memory,nvidia.com/gpu.family,nvidia.com/gpu.count

`llm-serve` asks for `nvidia.com/gpu.product: H100`. Compare that with the
real label values: GFD writes the full marketing name with dashes.
---
Node affinity operators go beyond equality: `Gt`/`Lt` compare a label's value
as an integer, `In` takes a list, `DoesNotExist` matches nodes that lack the
label. `nvidia.com/gpu.memory` is in MiB (an 80 GB H100 shows 81559).
Remember the template change only applies to new pods; the Deployments use
`Recreate`, so editing the template replaces the pods.
---
Replace each Deployment's placement with a required node affinity
(`spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms`):

- llm-serve: `{key: nvidia.com/gpu.memory, operator: Gt, values: ["70000"]}` and delete the nodeSelector
- whisper:   `{key: nvidia.com/gpu.family, operator: In, values: [turing, ampere]}`
- etl:       `{key: nvidia.com/gpu.present, operator: DoesNotExist}`

The ready-made files are in `solution/` (`kubectl apply -f solution/` from the lesson directory).
