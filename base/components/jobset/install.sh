# JobSet: a group of Jobs (e.g. the workers of a distributed training run)
# managed as one unit, with DNS for the pods, success and failure policies.
# Used by the training course. https://jobset.sigs.k8s.io
JOBSET_VERSION="${JOBSET_VERSION:-v0.13.0}"
url="https://github.com/kubernetes-sigs/jobset/releases/download/${JOBSET_VERSION}/manifests.yaml"
# The CRD is too large for client-side apply's last-applied annotation.
kubectl apply --server-side --force-conflicts -f "$url" >/dev/null
# Small requests (upstream asks for 500m CPU); tolerate the sim taint so the
# controller survives sim lessons of other courses; never on a fake node.
kubectl -n jobset-system patch deploy jobset-controller-manager --type=json -p '[
  {"op":"add","path":"/spec/template/spec/tolerations","value":[{"operator":"Exists"}]},
  {"op":"add","path":"/spec/template/spec/affinity","value":{"nodeAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"type","operator":"DoesNotExist"}]}]}}}},
  {"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources","value":
     {"requests":{"cpu":"20m","memory":"48Mi"},"limits":{"memory":"256Mi"}}}
]' >/dev/null
kubectl -n jobset-system rollout status deploy/jobset-controller-manager --timeout=300s >/dev/null
# The webhook serves with a self-generated certificate; wait until it answers.
probe() {
  kubectl create --dry-run=server -n default -f - >/dev/null 2>&1 <<'YAML'
apiVersion: jobset.x-k8s.io/v1alpha2
kind: JobSet
metadata:
  name: kdrill-webhook-probe
spec:
  replicatedJobs:
  - name: w
    template:
      spec:
        template:
          spec:
            restartPolicy: Never
            containers:
            - name: c
              image: busybox
YAML
}
wait_until 180 probe || die "jobset webhook did not become ready"
info "jobset ${JOBSET_VERSION} ready"
