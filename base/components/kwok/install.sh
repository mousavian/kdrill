# KWOK: fake nodes and pods. Always installed with the cluster.
KWOK_VERSION="${KWOK_VERSION:-v0.8.0}"
base="https://github.com/kubernetes-sigs/kwok/releases/download/${KWOK_VERSION}"
kubectl apply -f "${base}/kwok.yaml" >/dev/null
kubectl apply -f "${base}/stage-fast.yaml" >/dev/null
# The controller must keep running while the real node is tainted for sim lessons.
kubectl -n kube-system patch deploy kwok-controller --type=merge -p '{
  "spec":{"template":{"spec":{"tolerations":[{"operator":"Exists"}]}}}}' >/dev/null
kubectl -n kube-system rollout status deploy/kwok-controller --timeout=180s >/dev/null
info "kwok ${KWOK_VERSION} ready"
