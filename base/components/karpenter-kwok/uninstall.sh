# Remove Karpenter (KWOK provider). The built image stays in the local Docker
# image store so the next install is fast (docker rmi kdrill.local/karpenter-kwok:<ver>
# to reclaim it).
KARPENTER_VERSION="${KARPENTER_VERSION:-v1.15.1}"
NS=karpenter
CACHE="${KDRILL_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/kdrill}"
SRC="$CACHE/src/karpenter-${KARPENTER_VERSION}"

has_crd() { kubectl get crd "$1" >/dev/null 2>&1; }

# NodePools, NodeClaims and Karpenter's nodes carry finalizers that only the
# controller removes: delete them while it still runs, then strip what's left.
if has_crd nodepools.karpenter.sh; then
  kubectl delete nodepools.karpenter.sh --all --wait=false >/dev/null 2>&1 || true
  kubectl delete nodeclaims.karpenter.sh --all --timeout=60s >/dev/null 2>&1 || true
  for nc in $(kubectl get nodeclaims.karpenter.sh -o name 2>/dev/null); do
    kubectl patch "$nc" --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
  done
fi
for n in $(kubectl get nodes -l karpenter.sh/nodepool -o name 2>/dev/null); do
  kubectl patch "$n" --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
  kubectl delete "$n" --wait=false >/dev/null 2>&1 || true
done
if has_crd kwoknodeclasses.karpenter.kwok.sh; then
  for nc in $(kubectl get kwoknodeclasses.karpenter.kwok.sh -o name 2>/dev/null); do
    kubectl patch "$nc" --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
  done
  kubectl delete kwoknodeclasses.karpenter.kwok.sh --all --wait=false >/dev/null 2>&1 || true
fi
for np in $(kubectl get nodepools.karpenter.sh -o name 2>/dev/null); do
  kubectl patch "$np" --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
done

kubectl delete ns "$NS" --ignore-not-found --timeout=120s >/dev/null 2>&1 || true
kubectl delete clusterrole,clusterrolebinding -l app.kubernetes.io/instance=karpenter --ignore-not-found >/dev/null 2>&1 || true
kubectl delete clusterrole karpenter karpenter-core karpenter-admin --ignore-not-found >/dev/null 2>&1 || true
kubectl delete clusterrolebinding karpenter karpenter-core --ignore-not-found >/dev/null 2>&1 || true
kubectl delete role,rolebinding -n kube-system -l app.kubernetes.io/instance=karpenter --ignore-not-found >/dev/null 2>&1 || true
if [[ -d "$SRC/kwok/charts/crds" ]]; then
  kubectl delete --ignore-not-found --timeout=60s -f "$SRC/kwok/charts/crds/" >/dev/null 2>&1 || true
else
  kubectl delete crd nodepools.karpenter.sh nodeclaims.karpenter.sh nodeoverlays.karpenter.sh \
    kwoknodeclasses.karpenter.kwok.sh capacitybuffers.autoscaling.x-k8s.io --ignore-not-found --timeout=60s >/dev/null 2>&1 || true
fi
info "karpenter removed"
