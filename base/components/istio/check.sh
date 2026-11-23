# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n istio-system get deploy istiod >/dev/null
# a pod restarting right now is not a missing component: give it a minute
kubectl -n istio-system wait deploy/istiod --for=condition=Available --timeout=60s >/dev/null
kubectl -n istio-system get ds istio-cni-node ztunnel >/dev/null
