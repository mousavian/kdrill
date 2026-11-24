See where the pods are: `kubectl get pods -o wide`, and which zone each node is
in: `kubectl get nodes -L topology.kubernetes.io/zone`. Look at the Deployment's
pod template for anything restricting the zone.
---
Two changes in the pod template: remove the `nodeSelector`, and add a
`topologySpreadConstraints` entry. The scheduler then makes sure the number of
matching pods per topology domain (zone) never differs by more than `maxSkew`.
`kubectl explain deploy.spec.template.spec.topologySpreadConstraints` lists the fields.
---
    topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels: {app: api}

`kubectl edit deploy api` (delete the nodeSelector lines too), or
`kubectl apply -f solution/api.yaml`.
