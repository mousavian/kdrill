# Kueue: job queueing, GPU quotas, cohorts, gang admission. Used by gpu-scheduling.
KUEUE_VERSION="${KUEUE_VERSION:-v0.20.4}"
url="https://github.com/kubernetes-sigs/kueue/releases/download/${KUEUE_VERSION}/manifests.yaml"
# The CRDs are too large for client-side apply's last-applied annotation.
kubectl apply --server-side --force-conflicts -f "$url" >/dev/null
# The optional visibility API (pending-workload listing) is an aggregated
# APIService; while the controller restarts it breaks `kubectl api-resources`
# (and with it kdrill's cleanup), so we leave it out. `kubectl get workloads`
# shows the same information.
kubectl delete apiservice v1beta2.visibility.kueue.x-k8s.io --ignore-not-found >/dev/null
# Must keep running while sim lessons taint the real node; keep it small.
kubectl -n kueue-system patch deploy kueue-controller-manager --type=json -p '[
  {"op":"add","path":"/spec/template/spec/tolerations","value":[{"operator":"Exists"}]},
  {"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources","value":
     {"requests":{"cpu":"50m","memory":"96Mi"},"limits":{"memory":"384Mi"}}}
]' >/dev/null
kubectl -n kueue-system rollout status deploy/kueue-controller-manager --timeout=300s >/dev/null
# The webhook serves with a self-generated certificate; wait until it answers.
probe() {
  kubectl create --dry-run=server -f - >/dev/null 2>&1 <<'YAML'
apiVersion: kueue.x-k8s.io/v1beta2
kind: ResourceFlavor
metadata:
  name: kdrill-webhook-probe
YAML
}
wait_until 180 probe || die "kueue webhook did not become ready"
info "kueue ${KUEUE_VERSION} ready"
