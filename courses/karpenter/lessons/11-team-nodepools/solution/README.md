# Solution

    kubectl apply -f solution/team-a-nodepool.yaml -f solution/team-b-nodepool.yaml -f solution/apps.yaml   # from the lesson directory

- NodePools `team-a` (on-demand) and `team-b` (spot), each with template
  label `team: <pool>`, taint `team=<pool>:NoSchedule`, `limits.cpu: 16`.
- `etl` and `web` select `team: <their team>` and tolerate their taint.

The rollouts create new pods that only the matching team pool can serve
(`shared` doesn't set the `team` label), so Karpenter launches one node per
team; the old pods leave the shared nodes, and consolidation shrinks
`shared` to what `metrics` needs.

Why both a label and a taint:
- Without the taint, the next pod without selectors (e.g. a new platform
  service) may be packed onto a team node.
- Without the label/selector, a team's pods tolerate the taint but are just
  as happy on `shared`.

Weights aren't needed here because the pools are mutually exclusive: every
pod fits exactly one pool. Use weights when pools deliberately overlap
(spot before on-demand, reserved before on-demand).
