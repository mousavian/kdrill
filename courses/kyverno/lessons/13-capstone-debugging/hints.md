Reproduce each documented behaviour with a probe, then read the policy:

    kubectl create --dry-run=server -f probes/pod-no-owner.yaml -n payments
    kubectl create --dry-run=server -f probes/pod-dockerhub.yaml -n analytics
    kubectl create --dry-run=server -f probes/cronjob-root.yaml -n payments
    kubectl create --dry-run=server -f probes/pod-gpu.yaml -n payments -o yaml

Admitted when it should be rejected? Then the rule is in Audit, doesn't
match, or its pattern passes. Or a mutation is missing.
---
One bug class per policy, and one policy has two:
- 1: the rule reports but doesn't block.
- 2: look at the namespace labels (`kubectl get ns --show-labels`) vs the selector.
- 3: `=( )` means "only if present"; and the autogen annotation limits
  which controllers get a generated rule.
- 4: the rule that adds the toleration runs before the rule that adds the
  label it checks.
---
    kubectl apply -f solution/policies.yaml        # from the lesson directory
    kubectl -n payments rollout restart deploy fraud-model

Every fix is marked `# FIX n` in the solution file.
