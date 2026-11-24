# KEDA (event-driven autoscaling): the operator and the metrics API server, from
# the pinned release's "core" manifest (no admission webhooks, no HTTP add-on).
# Used by the inference course with the metrics-api scaler, so no Prometheus is
# needed. Keeps running while sim lessons taint the real node.
KEDA_VERSION="${KEDA_VERSION:-2.21.0}"
url="https://github.com/kedacore/keda/releases/download/v${KEDA_VERSION}/keda-${KEDA_VERSION}-core.yaml"
kubectl apply --server-side --force-conflicts -f "$url" >/dev/null
for d in keda-operator keda-metrics-apiserver; do
  kubectl -n keda patch deploy "$d" --type=json -p '[
    {"op":"add","path":"/spec/template/spec/tolerations","value":[{"operator":"Exists"}]},
    {"op":"add","path":"/spec/template/spec/nodeSelector","value":{"node-role.kubernetes.io/control-plane":"true"}},
    {"op":"replace","path":"/spec/template/spec/containers/0/resources","value":
       {"requests":{"cpu":"20m","memory":"48Mi"},"limits":{"memory":"256Mi"}}}
  ]' >/dev/null
done
for d in keda-operator keda-metrics-apiserver; do
  kubectl -n keda rollout status "deploy/$d" --timeout=300s >/dev/null
done
# the external metrics API (what an HPA reads) must answer before lessons start
ext_ok() { kubectl get --raw /apis/external.metrics.k8s.io/v1beta1 >/dev/null 2>&1; }
wait_until 120 ext_ok || die "KEDA's external metrics API did not become ready"
info "keda ${KEDA_VERSION} ready"
