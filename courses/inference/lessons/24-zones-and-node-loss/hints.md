    kubectl get pods -o wide
    kubectl get nodes -L topology.kubernetes.io/zone
    kubectl explain deployment.spec.template.spec.topologySpreadConstraints

The Deployment prefers zone-a (weight 100), so the scheduler fills zone-a's 4 GPUs first. Which 4 of the 6 are lost
if zone-a goes? Remove the preference and tell the scheduler what "evenly" means.
---
In the pod template: delete `affinity` and add

    topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
      labelSelector: {matchLabels: {app: llm}}
      matchLabelKeys: [pod-template-hash]

plus a PodDisruptionBudget (`maxUnavailable: 2` or `minAvailable: 4`). The constraint only governs where NEW pods go: the old pods
count as part of the spread and are deleted wherever they happen to be, so a rolling update can keep the old imbalance.
`matchLabelKeys: [pod-template-hash]` makes each new ReplicaSet spread by itself, and the rollout ends 2 + 2 + 2.
---
    kubectl apply -f solution/llm.yaml      # from the lesson directory
    kubectl apply -f solution/pdb.yaml
