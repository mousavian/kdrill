# Remove Istio completely: mesh config objects, the control plane, the CNI
# agent and ztunnel, Istio's CRDs and webhooks, and the Gateway API CRDs if
# install.sh added them. Lesson namespaces are removed by lesson cleanup.
set +e
here="$KDRILL_HOME/base/components/istio"
source "$here/istioctl.sh"
istioctl="$(istioctl_bin 2>/dev/null)"

# Gateways first, while istiod still runs (it owns the generated Deployments).
kubectl delete gateways.gateway.networking.k8s.io --all -A --ignore-not-found --timeout=60s >/dev/null 2>&1
if [[ -n "$istioctl" ]]; then
  "$istioctl" uninstall --purge -y >/dev/null 2>&1
fi
# Whatever istioctl left behind (or everything, if istioctl was unavailable).
kubectl delete mutatingwebhookconfiguration,validatingwebhookconfiguration -l app=sidecar-injector --ignore-not-found >/dev/null 2>&1
kubectl delete validatingwebhookconfiguration istio-validator-istio-system istiod-default-validator --ignore-not-found >/dev/null 2>&1
kubectl get crd -o name 2>/dev/null | grep -E '\.istio\.io$' | xargs -r kubectl delete --ignore-not-found --timeout=60s >/dev/null 2>&1
kubectl delete ns istio-system --ignore-not-found --timeout=120s >/dev/null 2>&1
kubectl delete crd -l kdrill.dev/installed-by=istio --ignore-not-found --timeout=60s >/dev/null 2>&1
kubectl delete validatingadmissionpolicy,validatingadmissionpolicybinding safe-upgrades.gateway.networking.k8s.io --ignore-not-found >/dev/null 2>&1
info "istio removed"
