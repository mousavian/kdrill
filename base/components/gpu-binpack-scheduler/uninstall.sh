kubectl -n kube-system delete deploy/gpu-binpack-scheduler configmap/gpu-binpack-scheduler \
  serviceaccount/gpu-binpack-scheduler rolebinding/gpu-binpack-scheduler:auth-reader --ignore-not-found >/dev/null
kubectl delete clusterrolebinding gpu-binpack-scheduler:kube-scheduler gpu-binpack-scheduler:volume-scheduler --ignore-not-found >/dev/null
info "gpu-binpack scheduler removed"
