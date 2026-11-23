# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n envoy-gateway-system get deploy envoy-gateway -o jsonpath='{.status.availableReplicas}' | grep -qx '[1-9][0-9]*'
[[ "$(kubectl get gatewayclass eg -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}')" == True ]]
