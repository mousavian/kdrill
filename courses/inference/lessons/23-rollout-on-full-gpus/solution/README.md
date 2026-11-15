# Solution

From the lesson directory:

    kubectl apply -f solution/llm.yaml
    kubectl apply -f solution/pdb.yaml

    strategy.rollingUpdate: {maxSurge: 1, maxUnavailable: 0}
    tolerations: [{key: capacity, operator: Equal, value: spare, effect: NoSchedule}]
    PodDisruptionBudget: minAvailable: 4

With `maxSurge: 1, maxUnavailable: 0` the Deployment creates one new pod first, waits until it is ready, and only then
stops an old pod: capacity never drops below 4. The surge pod needs a free GPU and the only one is on
`spare-1`; the node's taint `capacity=spare:NoSchedule` keeps ordinary pods away, so the model pods
need the matching toleration. Each step reuses the spare GPU: new pod on spare-1, old pod gone from `main-1`,
the next new pod fits on the freed GPU of `main-1` (the scheduler prefers a node
with room), and so on; the spare GPU is only borrowed during the rollout.

This is the trade lesson 12 described: **either** spare capacity (pay for 1 extra GPU, or keep it on cheaper spot
nodes, tainted so nothing else uses it) **or** a dip in capacity (`maxSurge: 0`). The PDB
`minAvailable: 4` covers other voluntary disruptions (node drain for an upgrade, cluster autoscaler scale-down): they
must wait while any replica is missing.

For critical models many teams run N+1 permanently (one more replica than the load needs), so even a
failed node or a rollout leaves enough capacity; the next lessons plan exactly that.
