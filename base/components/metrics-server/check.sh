# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n kube-system get deploy metrics-server -o jsonpath='{.status.availableReplicas}' | grep -qx '[1-9][0-9]*'
