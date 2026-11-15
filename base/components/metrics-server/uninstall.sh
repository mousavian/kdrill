set +e
MS_VERSION="${MS_VERSION:-v0.9.1}"
kubectl delete -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${MS_VERSION}/components.yaml" --ignore-not-found --timeout=120s >/dev/null 2>&1
kubectl delete apiservice v1beta1.metrics.k8s.io --ignore-not-found >/dev/null 2>&1
info "metrics-server removed"
