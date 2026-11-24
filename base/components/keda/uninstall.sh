# Remove KEDA completely: ScaledObjects first (so HPAs they own go away), then the
# manifest (which includes the CRDs and the external-metrics APIService).
set +e
kubectl delete scaledobjects.keda.sh,scaledjobs.keda.sh,triggerauthentications.keda.sh,clustertriggerauthentications.keda.sh --all -A --ignore-not-found --timeout=60s >/dev/null 2>&1
KEDA_VERSION="${KEDA_VERSION:-2.21.0}"
kubectl delete -f "https://github.com/kedacore/keda/releases/download/v${KEDA_VERSION}/keda-${KEDA_VERSION}-core.yaml" --ignore-not-found --timeout=120s >/dev/null 2>&1
kubectl delete apiservice v1beta1.external.metrics.k8s.io --ignore-not-found >/dev/null 2>&1
kubectl get crd -o name 2>/dev/null | grep -E '\.keda\.sh$' | xargs kubectl delete --ignore-not-found --timeout=60s >/dev/null 2>&1
kubectl delete ns keda --ignore-not-found --timeout=120s >/dev/null 2>&1
info "keda removed"
