# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n envoy-gateway-system get deploy envoy-gateway >/dev/null
# a pod restarting right now is not a missing component: give it a minute
kubectl -n envoy-gateway-system wait deploy/envoy-gateway --for=condition=Available --timeout=60s >/dev/null
[[ "$(kubectl get gatewayclass eg -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}')" == True ]]
