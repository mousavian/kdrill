Which device did each pod get?

    kubectl get resourceclaims
    kubectl get resourceclaim <name> -o jsonpath='{.status.allocation.devices.results}'
    kubectl get resourceslices -o yaml | grep -E '  - name:|productName|memory'

Device names here encode the model (`l4-0`, `l40s-1`, `h100-2`). The
templates only name the DeviceClass, so the scheduler takes whatever is free.
---
Add `selectors: [{cel: {expression: ...}}]` and `count` to the template
requests. Templates are immutable: `kubectl delete resourceclaimtemplate
gpu-40g two-h100`, then create the new versions, then
`kubectl rollout restart deploy llm trainer` so new pods get new claims.
For sharing you need a ResourceClaim (not a template) referenced by
`resourceClaimName` from both Deployments.
---
From the lesson directory:

    kubectl delete resourceclaimtemplate gpu-40g two-h100
    kubectl apply -f solution/claims.yaml            # 2 fixed templates + ResourceClaim shared-l4
    kubectl apply -f solution/encoder-decoder.yaml   # both use resourceClaimName: shared-l4
    kubectl rollout restart deploy llm trainer
