# Spread the API across zones

## Concept

Cloud nodes live in **failure domains**: zones, racks, regions. If all replicas
of a service share one zone, a zone outage takes the whole service down — no
matter how many replicas you have.

A **topology spread constraint** tells the scheduler to distribute matching
pods evenly over the values of a node label (the `topologyKey`):

    topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels: {app: api}

- `topologyKey` — the node label that defines a domain (each distinct value is
  one domain).
- `labelSelector` — which pods are counted. It should match the pods of this
  workload.
- `maxSkew` — the largest allowed difference between the domain with the most
  matching pods and the one with the fewest.
- `whenUnsatisfiable` — `DoNotSchedule` makes it a hard rule (the pod stays
  Pending if placing it would exceed maxSkew); `ScheduleAnyway` makes it a
  scoring preference only.

With 6 pods over 3 zones and `maxSkew: 1`, each new pod must go to a zone that
keeps the counts within 1 of each other, which ends at 2 / 2 / 2.

Things to remember: the constraint is checked only when a pod is scheduled — it
never moves running pods — and it works alongside, not instead of, nodeSelector
and affinity: a rule that confines pods to one zone leaves nothing to spread.

## The situation

Six nodes in three zones, two nodes each:

    kubectl get nodes -L topology.kubernetes.io/zone

The `api` Deployment has 6 replicas, and a colleague added a `nodeSelector`
for zone `a` "for latency". All six pods are in one zone.

## Your task

Make `api` run exactly 2 pods per zone using a topology spread constraint.

Rules:
- Add a `topologySpreadConstraints` entry on `topology.kubernetes.io/zone` with
  `maxSkew: 1`, `whenUnsatisfiable: DoNotSchedule`, and a `labelSelector`
  that selects the api pods (`app: api`).
- Remove the zone `nodeSelector` (and don't replace it with a required zone
  affinity).
- Keep 6 replicas, all ready. Don't change the nodes or their labels.

## Useful commands

    kubectl get nodes -L topology.kubernetes.io/zone
    kubectl get pods -o wide
    kubectl explain deploy.spec.template.spec.topologySpreadConstraints
    kubectl edit deploy api

When you think you're done: `kdrill verify`

## Read more

- https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/
- https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
