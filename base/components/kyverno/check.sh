# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n kyverno get deploy kyverno-admission-controller -o jsonpath='{.status.availableReplicas}' | grep -qx '[1-9][0-9]*'
kubectl get crd clusterpolicies.kyverno.io >/dev/null
