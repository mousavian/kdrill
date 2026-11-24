JOBSET_VERSION="${JOBSET_VERSION:-v0.13.0}"
url="https://github.com/kubernetes-sigs/jobset/releases/download/${JOBSET_VERSION}/manifests.yaml"
# Delete JobSets while the controller still runs (it owns their child Jobs).
kubectl delete jobsets.jobset.x-k8s.io --all -A --ignore-not-found --timeout=60s >/dev/null 2>&1 || true
kubectl delete --ignore-not-found --wait=false -f "$url" >/dev/null 2>&1 || true
kubectl delete ns jobset-system --ignore-not-found --timeout=120s >/dev/null 2>&1 || true
info "jobset removed"
