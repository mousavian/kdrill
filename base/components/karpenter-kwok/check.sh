# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n karpenter get deploy karpenter -o jsonpath='{.status.availableReplicas}' | grep -qx '[1-9][0-9]*'
kubectl get crd nodepools.karpenter.sh >/dev/null
