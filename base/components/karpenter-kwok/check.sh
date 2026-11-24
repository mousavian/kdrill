# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n karpenter get deploy karpenter >/dev/null
# a pod restarting right now is not a missing component: give it a minute
kubectl -n karpenter wait deploy/karpenter --for=condition=Available --timeout=60s >/dev/null
kubectl get crd nodepools.karpenter.sh >/dev/null
