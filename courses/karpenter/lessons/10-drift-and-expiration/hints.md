Everything goes into NodePool `default`: `kubectl edit nodepool default`.
Labels for the nodes live in `spec.template.metadata.labels`;
`expireAfter` and `terminationGracePeriod` live in `spec.template.spec`.
---
After saving, look at the old NodeClaim: `kubectl get nodeclaim -o yaml |
grep -A3 Drifted`. Karpenter replaces drifted nodes on its own: launch the
new arm64 node, drain the old one (the PDB lets one api pod go at a time),
remove it. Don't delete anything yourself.
---
    kubectl apply -f solution/nodepool.yaml      # from the lesson directory
    kubectl get nodeclaims -w
