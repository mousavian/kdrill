KUEUE_VERSION="${KUEUE_VERSION:-v0.20.4}"
url="https://github.com/kubernetes-sigs/kueue/releases/download/${KUEUE_VERSION}/manifests.yaml"
# Kueue objects carry finalizers that only the controller removes: delete them
# while it is still running, then remove the installation.
for kind in workloads.kueue.x-k8s.io localqueues.kueue.x-k8s.io; do
  kubectl delete "$kind" --all -A --ignore-not-found --timeout=60s >/dev/null 2>&1 || true
done
for kind in clusterqueues.kueue.x-k8s.io cohorts.kueue.x-k8s.io resourceflavors.kueue.x-k8s.io topologies.kueue.x-k8s.io; do
  kubectl delete "$kind" --all --ignore-not-found --timeout=60s >/dev/null 2>&1 || true
done
kubectl delete --ignore-not-found --wait=false -f "$url" >/dev/null 2>&1 || true
kubectl delete ns kueue-system --ignore-not-found --timeout=120s >/dev/null 2>&1 || true
info "kueue removed"
