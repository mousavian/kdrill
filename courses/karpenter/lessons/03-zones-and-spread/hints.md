`reports` first: `kubectl -n store describe pod -l app=reports | tail -5`.
Which zones exist? `kubectl get nodes -L topology.kubernetes.io/zone`, or
the catalogue: every type is offered in us-west-2a, b and c.

For `checkout`: `kubectl explain deployment.spec.template.spec.topologySpreadConstraints`.
---
A zone spread with only `maxSkew` and `DoNotSchedule` isn't enough here:
while all nodes are in one zone, the scheduler sees a single zone and keeps
packing pods into it. `minDomains: 3` makes it count the two empty zones as
0, so pods wait and Karpenter launches nodes in those zones. Add
`matchLabelKeys: [pod-template-hash]` so old pods don't skew the new
rollout.
---
    kubectl apply -f solution/apps.yaml      # from the lesson directory

`checkout` gets a zone spread constraint (maxSkew 1, DoNotSchedule,
minDomains 3, matchLabelKeys pod-template-hash); `reports` asks for
us-west-2a.
