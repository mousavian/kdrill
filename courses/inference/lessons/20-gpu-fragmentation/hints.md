    kubectl get pods -o wide -L app
    kubectl describe pod -l app=llm-70b | tail -5
    kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu

6 + 4 = 10 GPUs are requested and the fleet has 8, so at most 4 small replicas fit next to the big one. But there is a
second problem: the scheduler spread the 8B pods over both nodes (3 + 3), so no node has 4 free GPUs. Free GPUs are only useful when
they are on the same node as the pod that needs them.
---
Two changes to `llm-8b`: `replicas: 4`, and a `nodeSelector` (for example `kubernetes.io/hostname: a100-2`)
so that all small replicas live on one node and the other node stays empty for the 70B pod.
The rollout reschedules the 8B pods; the Pending 70B pod then finds 4 free GPUs on a100-1.
---
    kubectl apply -f solution/llm-8b.yaml      # from the lesson directory
    kubectl get pods -o wide
