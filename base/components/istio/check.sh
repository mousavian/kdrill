# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n istio-system get deploy istiod -o jsonpath='{.status.availableReplicas}' | grep -qx '[1-9][0-9]*'
kubectl -n istio-system get ds istio-cni-node ztunnel >/dev/null
