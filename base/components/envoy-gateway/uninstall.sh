# Remove Envoy Gateway completely: Gateways (and with them their Envoy
# Deployments), GatewayClass, the helm release, CRDs and the namespace.
set +e
# Gateways first, while the controller still runs, so it removes the Envoy
# Deployments/Services it created in the Gateways' namespaces.
kubectl delete gateways.gateway.networking.k8s.io --all -A --ignore-not-found --timeout=60s >/dev/null 2>&1
kubectl delete gatewayclass eg --ignore-not-found --timeout=60s >/dev/null 2>&1
helm uninstall eg -n envoy-gateway-system --wait --timeout 3m >/dev/null 2>&1
# Anything still carrying a finalizer of the (now gone) controller.
for k in gatewayclasses.gateway.networking.k8s.io; do
  for o in $(kubectl get "$k" -o name 2>/dev/null); do
    kubectl patch "$o" --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1
  done
done
# helm never deletes CRDs it installed from the chart's crds/ directory.
kubectl get crd -o name 2>/dev/null | grep -E '\.(gateway\.networking\.k8s\.io|gateway\.networking\.x-k8s\.io|gateway\.envoyproxy\.io)$' \
  | xargs kubectl delete --ignore-not-found --timeout=60s >/dev/null 2>&1
kubectl delete validatingadmissionpolicy,validatingadmissionpolicybinding safe-upgrades.gateway.networking.k8s.io --ignore-not-found >/dev/null 2>&1
kubectl delete clusterrole,clusterrolebinding -l app.kubernetes.io/instance=eg --ignore-not-found >/dev/null 2>&1
kubectl delete ns envoy-gateway-system --ignore-not-found --timeout=120s >/dev/null 2>&1
info "envoy gateway removed"
