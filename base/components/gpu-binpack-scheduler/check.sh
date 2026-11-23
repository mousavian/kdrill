# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n kube-system get deploy gpu-binpack-scheduler >/dev/null
# a pod restarting right now is not a missing component: give it a minute
kubectl -n kube-system wait deploy/gpu-binpack-scheduler --for=condition=Available --timeout=60s >/dev/null
