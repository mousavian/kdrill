`kubectl -n ml get pods -o wide`: everything sits on one GPU node. Karpenter
packed them together because nothing says web can't go there. A taint on the
GPU pool's nodes says exactly that:
`kubectl explain nodepool.spec.template.spec.taints`.
---
Add to NodePool `gpu`:

    spec.template.spec.taints: [{key: nvidia.com/gpu, value: "true", effect: NoSchedule}]

and to `inference`'s pod template a toleration for key `nvidia.com/gpu`
(`operator: Exists`, `effect: NoSchedule`). Then watch the old GPU node get
drifted and replaced: `kubectl get nodeclaims -w`.
---
    kubectl apply -f solution/gpu-nodepool.yaml -f solution/inference.yaml   # from the lesson directory
