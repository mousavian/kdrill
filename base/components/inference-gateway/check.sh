# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl get crd inferencepools.inference.networking.k8s.io inferenceobjectives.llm-d.ai inferencemodelrewrites.llm-d.ai >/dev/null
kubectl -n envoy-gateway-system get cm envoy-gateway-config -o jsonpath='{.data.envoy-gateway\.yaml}' | grep -q 'enableLua: true'
