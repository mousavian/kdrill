# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n kyverno get deploy kyverno-admission-controller >/dev/null
# a pod restarting right now is not a missing component: give it a minute
kubectl -n kyverno wait deploy/kyverno-admission-controller --for=condition=Available --timeout=60s >/dev/null
kubectl get crd clusterpolicies.kyverno.io >/dev/null
