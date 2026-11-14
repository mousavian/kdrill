Triage by symptom. Pending pods: `kubectl -n <ns> describe pod -l app=<name>`
and read the event from `karpenter`, not only the one from the scheduler.
Fleet not rolling: `kubectl get nodeclaims` shows a `Drifted` node; its
events say what blocks it.
---
The five causes are all different: a zone from another region, a missing
toleration for a NodePool taint, a pod pinned to a GPU model that only comes
as an 8-GPU instance, a `capacity-type: spot` pin that forbids the fallback
once the spot pool hits its limit, and a stale `karpenter.sh/do-not-disrupt`
annotation. Once embed and rerank both run, check idle GPUs: two 1-GPU pods
pending together get packed onto a multi-GPU node unless they ask for
`instance-gpu-count: "1"`.
---
    kubectl apply -f solution/prod.yaml -f solution/ml.yaml -f solution/batch.yaml   # from the lesson directory

Each fix is marked `# FIX n` in the solution files.
