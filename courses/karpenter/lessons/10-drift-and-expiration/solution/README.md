# Solution

    kubectl apply -f solution/nodepool.yaml      # from the lesson directory

The change touches requirements (arm64) and the template (label,
`expireAfter`, `terminationGracePeriod`). Within seconds the old NodeClaim
shows `Drifted=True` (reason `RequirementsDrifted`: an amd64 node can't
satisfy `arch In [arm64]`). Karpenter then:

1. launches a replacement: `DisruptionLaunching ... Drifted`, an `m7g` node
   labelled `fleet=graviton-2026`;
2. once it's Ready, taints the old node `karpenter.sh/disrupted:NoSchedule`
   and evicts its pods (the PDB lets one api pod go at a time);
3. deletes the old NodeClaim: `DisruptionTerminating ... Drifted`.

With more nodes, the default budget (10 % of the pool) would replace them a
few at a time.

Notes:
- The same mechanism handles AMI updates on AWS (NodeClass drift).
- `expireAfter: 168h` recycles every node weekly; expiry doesn't wait for
  budgets, and `terminationGracePeriod: 1h` guarantees no drain (drift or
  expiry) takes longer than an hour, even if a PDB or a do-not-disrupt pod
  would block it.
