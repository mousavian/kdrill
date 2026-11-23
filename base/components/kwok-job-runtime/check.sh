# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl get stage pod-complete -o jsonpath='{.spec.delay.durationFrom.expressionFrom}' | grep -q 'pod-complete.stage.kwok.x-k8s.io/delay'
