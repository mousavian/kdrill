# metrics-server (resource metrics for `kubectl top` and CPU-based HPAs). k3s is
# started without it. Pinned release; kubelet certificates are not verified (the
# lab's kubelet uses a self-signed cert), one small pod that survives sim lessons.
MS_VERSION="${MS_VERSION:-v0.9.1}"
kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${MS_VERSION}/components.yaml" >/dev/null
kubectl -n kube-system patch deploy metrics-server --type=json -p '[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
  {"op":"add","path":"/spec/template/spec/tolerations","value":[{"operator":"Exists"}]},
  {"op":"add","path":"/spec/template/spec/nodeSelector","value":{"node-role.kubernetes.io/control-plane":"true"}},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources","value":
     {"requests":{"cpu":"10m","memory":"32Mi"},"limits":{"memory":"96Mi"}}}
]' >/dev/null
kubectl -n kube-system rollout status deploy/metrics-server --timeout=300s >/dev/null
top_ok() { kubectl top node >/dev/null 2>&1; }
wait_until 180 top_ok || die "metrics-server did not start serving node metrics"
info "metrics-server ${MS_VERSION} ready"
