Copy `shared` as a starting point: `kubectl get nodepool shared -o yaml`.
Each team pool needs `spec.template.metadata.labels.team`,
`spec.template.spec.taints`, its own capacity-type requirement and
`spec.limits.cpu: "16"`.
---
The workloads need both halves: `nodeSelector: {team: team-a}` (only the
team-a pool sets that label, so only it can provision for them) and a
toleration for `team=team-a:NoSchedule` (so they're allowed onto those
nodes). `platform/metrics` has neither, so it can only use `shared`.
---
    kubectl apply -f solution/team-a-nodepool.yaml -f solution/team-b-nodepool.yaml -f solution/apps.yaml   # from the lesson directory
