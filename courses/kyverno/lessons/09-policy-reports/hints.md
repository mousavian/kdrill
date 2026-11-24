There are no reports yet. Why?

    kubectl get policyreports -A
    kubectl get clusterpolicy best-practices -o jsonpath='{.spec.background}'

Set `spec.background: true` (kubectl edit, or apply a changed copy) and wait
a few seconds.
---
Read the reports. One report per resource; `-o wide` adds the counts:

    kubectl get polr -n team-a -o wide
    kubectl -n team-a get polr <name> -o yaml        # results[]: policy, rule, result, message

Three Deployments fail: one `:latest` image, one untagged image (that's
`:latest` too), one container without a memory limit. Fix their Pod
templates (`kubectl set image`, `kubectl edit`). Old ReplicaSets keep their
failing reports until they are cleaned up; verify only counts Deployments
and Pods.
---
From the lesson directory:

    kubectl patch clusterpolicy best-practices --type=merge -p '{"spec":{"background":true}}'
    kubectl apply -f solution/workloads.yaml       # fixed worker, cache, embedder
    kubectl apply -f solution/policy.yaml          # background + Enforce
