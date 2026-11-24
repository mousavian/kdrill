KWOK_VERSION="${KWOK_VERSION:-v0.8.0}"
base="https://github.com/kubernetes-sigs/kwok/releases/download/${KWOK_VERSION}"
kubectl delete --ignore-not-found -f "${base}/stage-fast.yaml" >/dev/null
kubectl delete --ignore-not-found -f "${base}/kwok.yaml" >/dev/null
