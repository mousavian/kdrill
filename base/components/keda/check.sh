# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n keda get deploy keda-operator -o jsonpath='{.status.availableReplicas}' | grep -qx '[1-9][0-9]*'
kubectl -n keda get deploy keda-metrics-apiserver -o jsonpath='{.status.availableReplicas}' | grep -qx '[1-9][0-9]*'
