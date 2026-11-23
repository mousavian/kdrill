# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n kueue-system get deploy kueue-controller-manager >/dev/null
# a pod restarting right now is not a missing component: give it a minute
kubectl -n kueue-system wait deploy/kueue-controller-manager --for=condition=Available --timeout=60s >/dev/null
