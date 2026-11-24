# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n keda get deploy keda-operator >/dev/null
# a pod restarting right now is not a missing component: give it a minute
kubectl -n keda wait deploy/keda-operator --for=condition=Available --timeout=60s >/dev/null
kubectl -n keda get deploy keda-metrics-apiserver >/dev/null
# a pod restarting right now is not a missing component: give it a minute
kubectl -n keda wait deploy/keda-metrics-apiserver --for=condition=Available --timeout=60s >/dev/null
