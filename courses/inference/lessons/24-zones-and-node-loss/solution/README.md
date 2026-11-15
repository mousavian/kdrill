# Solution

From the lesson directory:

    kubectl apply -f solution/llm.yaml
    kubectl apply -f solution/pdb.yaml

The preferred node affinity for `zone-a` is removed and replaced by

    topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
      labelSelector: {matchLabels: {app: llm}}
      matchLabelKeys: [pod-template-hash]

so the number of `llm` pods in any zone differs from any other zone by at most 1: with 6 replicas and 3 zones, 2 + 2 + 2.
`matchLabelKeys: [pod-template-hash]` matters during the rolling update: without it the old pods (4 in zone-a) count in the spread
and are removed wherever they are, so the new pods can never fix the imbalance on their own; with it the new ReplicaSet spreads 2 + 2 + 2 by itself.
A PDB with `maxUnavailable: 2` allows at most one zone's worth of voluntary evictions at a time.

Node-loss drill: when `gpu-a` disappears the Deployment loses 2 replicas; the new pods have to go somewhere
under the same constraint. Only zones that have a node count as domains, so zone-b and zone-c take 3 each (skew 0). With
`DoNotSchedule` the replacements wait for a legal place instead of piling up on one node; with `ScheduleAnyway` the spread
is a mere preference, which is how a "balanced" fleet quietly becomes unbalanced again.

For a model server, spreading is availability insurance and also a capacity question: if one zone's GPUs vanish (zone outage,
spot reclamation, quota), the remaining replicas must carry the traffic, so the replica count is chosen as `needed / (1 - lost share)`: lesson 25 does the arithmetic.
Spread across *nodes* too (`kubernetes.io/hostname`, maxSkew 1) when a node holds several GPUs and a replica uses one.
