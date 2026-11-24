# Istio service mesh (istiod + istio-cni + ztunnel, profile "ambient") and the
# Kubernetes Gateway API CRDs. Used by the istio course. Pinned versions; the
# lean settings live in istio-operator.yaml next to this script.
#
# Installed with the pinned istioctl (downloaded into the kdrill state
# directory), which carries Istio's charts for its own version: Istio 1.31
# is not published to the classic helm repository, and the lessons need
# istioctl anyway.
GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-v1.6.3}"
here="$KDRILL_HOME/base/components/istio"
source "$here/istioctl.sh"
command -v curl >/dev/null || die "curl is required for the istio component"
istioctl="$(istioctl_bin)" || die "could not get istioctl $ISTIO_VERSION"

# Gateway API CRDs (ingress lessons, waypoints). Leave a newer or existing
# install alone; mark the ones we add so uninstall.sh only removes those.
if ! kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
  kubectl apply --server-side --force-conflicts \
    -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml" >/dev/null
  kubectl label $(kubectl get crd -o name | grep '\.gateway\.networking\.k8s\.io$') \
    kdrill.dev/installed-by=istio --overwrite >/dev/null
  kubectl wait crd -l kdrill.dev/installed-by=istio --for=condition=Established --timeout=60s >/dev/null
fi

if ! out="$("$istioctl" install -y -f "$here/istio-operator.yaml" 2>&1)"; then
  printf '%s\n' "$out" | tail -20 >&2
  die "istioctl install failed"
fi

kubectl -n istio-system rollout status deploy/istiod --timeout=300s >/dev/null
kubectl -n istio-system rollout status ds/istio-cni-node --timeout=300s >/dev/null
kubectl -n istio-system rollout status ds/ztunnel --timeout=300s >/dev/null

# The sidecar injector webhook is ready when a dry-run Pod in an injected
# namespace comes back with an istio-proxy container.
kubectl create ns kdrill-istio-probe >/dev/null 2>&1 || true
kubectl label ns kdrill-istio-probe istio-injection=enabled --overwrite >/dev/null
probe() {
  local out
  out="$(kubectl -n kdrill-istio-probe run probe --image=busybox --restart=Never --dry-run=server -o jsonpath='{.spec.initContainers[*].name} {.spec.containers[*].name}' 2>/dev/null)"
  [[ "$out" == *istio-proxy* ]]
}
ok=0; wait_until 120 probe && ok=1
kubectl delete ns kdrill-istio-probe --ignore-not-found --wait=false >/dev/null 2>&1 || true
(( ok == 1 )) || die "the istio sidecar injector did not become ready"
info "istio $ISTIO_VERSION ready (istiod, istio-cni, ztunnel; Gateway API $(kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}'))"
info "istioctl: $istioctl"
