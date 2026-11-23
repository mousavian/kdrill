# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n jobset-system get deploy jobset-controller-manager >/dev/null
# a pod restarting right now is not a missing component: give it a minute
kubectl -n jobset-system wait deploy/jobset-controller-manager --for=condition=Available --timeout=60s >/dev/null
