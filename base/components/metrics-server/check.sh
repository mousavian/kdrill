# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n kube-system get deploy metrics-server >/dev/null
# a pod restarting right now is not a missing component: give it a minute
kubectl -n kube-system wait deploy/metrics-server --for=condition=Available --timeout=60s >/dev/null
