# Solution

    kubectl apply -f solution/apps.yaml      # from the lesson directory

- `reports`: `nodeSelector: {topology.kubernetes.io/zone: us-west-2a}`. Before,
  Karpenter's event said `no instance type met the scheduling requirements
  or had enough resources or had a required offering` and listed the combined
  requirements, ending in `topology.kubernetes.io/zone In [us-west-2d]`: no
  offering exists in that zone. Now it launches a node in us-west-2a (a `c6i.large` fits
  both pods).
- `checkout`:

      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        minDomains: 3
        labelSelector: {matchLabels: {app: checkout}}
        matchLabelKeys: [pod-template-hash]

  The rollout creates new pods. With `minDomains: 3` the scheduler treats the
  zones without nodes as having 0 pods, so only a couple fit in the existing
  zone; the rest go Pending. Karpenter simulates the same constraint and
  creates NodeClaims pinned to the missing zones (watch the ZONE column of
  `kubectl get nodeclaims`). Old pods terminate, and consolidation replaces
  the old, now half-empty node with a smaller one.

Without `minDomains` you'd likely see 6 pods in one zone and a passing
"spread" constraint: one domain, skew 0. Without `matchLabelKeys`, old and
new pods are counted together during the rollout and the result is uneven.
