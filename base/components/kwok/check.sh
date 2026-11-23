# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n kube-system get deploy kwok-controller >/dev/null
# a pod restarting right now is not a missing component: give it a minute
kubectl -n kube-system wait deploy/kwok-controller --for=condition=Available --timeout=60s >/dev/null
kubectl get stage pod-complete >/dev/null
