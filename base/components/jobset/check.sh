# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n jobset-system get deploy jobset-controller-manager -o jsonpath='{.status.availableReplicas}' | grep -qx '[1-9][0-9]*'
