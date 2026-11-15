# Spreading replicas across zones and surviving a node loss

Fake pods on fake GPU nodes in three zones (**no request is ever served**).

## Concept

Replicas only add availability if they fail independently. A rack, a zone, a spot
reclamation wave or a bad node image can take out several nodes at once, so a model that
runs 6 replicas on 6 GPUs of one zone is "one outage" away from serving nothing.
Kubernetes' tool is the **topology spread constraint**: for a label selector, a
`topologyKey` (zone, node...), a `maxSkew` (how unequal the counts may be) and
`whenUnsatisfiable` (`DoNotSchedule` = a rule, `ScheduleAnyway` = a preference). Leftover node
affinities (`preferred` ones are easy to forget), a nodeSelector for a single zone or a GPU
type that only exists in one zone silently defeat it.

Scale-in the other direction matters too: when a node disappears the Deployment recreates the
lost pods, and the scheduler must place them without breaking the constraint; GPU capacity left in the
surviving zones decides whether they run or stay Pending (lesson 25 plans for that). A **PodDisruptionBudget** limits
how many replicas voluntary disruptions (drains, upgrades) may take down at once, but it cannot
help against failures: those are involuntary.

## The situation

Three fake nodes with 4 GPUs each, one per zone (`gpu-a` in `zone-a`, `gpu-b`, `gpu-c`). The Deployment `llm` (6 replicas, 1 GPU
each) has a leftover *preferred* node affinity for `zone-a`; 4 replicas run there, 1 in each other zone.

## Your task

- remove the zone-a preference; add a topology spread constraint over `topology.kubernetes.io/zone`
  with `maxSkew: 1` and `whenUnsatisfiable: DoNotSchedule`;
- a PodDisruptionBudget on `app=llm` allowing at most 2 down (`maxUnavailable: 2` or
  `minAvailable: 4`);
- six replicas Running, two per zone;
- verify then deletes the node `gpu-a` (the drill): the six replicas must be Running again within 90 s,
  none on the lost node, 3 + 3 over the surviving zones. Afterwards it recreates the node and deletes
  one replica in each surviving zone, so that the fleet is back at 2 + 2 + 2 (the scheduler never
  moves running pods by itself).

## Useful commands

    kubectl get pods -o wide
    kubectl get nodes -L topology.kubernetes.io/zone
    kubectl explain deployment.spec.template.spec.topologySpreadConstraints
    kubectl get pdb

When you think you're done: `kdrill verify` (the drill takes up to a minute and a half).

## On a real cluster

Nodes carry the zone label automatically (`topology.kubernetes.io/zone`). Autoscalers create nodes
per zone to satisfy the constraint (watch out for `DoNotSchedule` blocking scale-out when
a zone has no GPU quota). Use `matchLabelKeys: [pod-template-hash]` so that a rolling update spreads the new
pods independently of the old ones. For multi-region inference add a global load balancer in front.

## Read more

- https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/
- https://kubernetes.io/docs/concepts/architecture/nodes/#node-controller
- https://kubernetes.io/docs/tasks/run-application/configure-pdb/
