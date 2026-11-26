# Kubeflow Trainer v2 (TrainJob, TrainingRuntime, ClusterTrainingRuntime): the
# controller, its four CRDs and its webhooks. Used by the kubeflow-trainer course.
# https://www.kubeflow.org/docs/components/trainer/
#
# Needs the jobset component first (a TrainJob creates a JobSet; Trainer v2.4.0 is built
# against JobSet v0.13.0, the version the jobset component installs).
# The stock ClusterTrainingRuntimes (torch-distributed, ...) are NOT installed: they point at
# multi-gigabyte upstream images; the lessons define runtimes around kdrill.local/ml-tiny.
TRAINER_VERSION="${TRAINER_VERSION:-v2.4.0}"
here="$KDRILL_HOME/base/components/kubeflow-trainer"
cache="${KDRILL_STATE_DIR:-$HOME/.kdrill}/cache/kubeflow-trainer-$TRAINER_VERSION"

kubectl get crd jobsets.jobset.x-k8s.io >/dev/null 2>&1 || die "the JobSet CRD is missing: install the jobset component first"

# --- CRDs: ~2.5 MB of YAML, downloaded once from the pinned tag and checked against crds.sha256
mkdir -p "$cache"
sha_of() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' || true; }
while read -r sum file; do
  [[ "$(sha_of "$cache/$file")" == "$sum" ]] && continue
  info "downloading $file ($TRAINER_VERSION)"
  curl -fsSL --retry 3 -o "$cache/$file.part" \
    "https://raw.githubusercontent.com/kubeflow/trainer/$TRAINER_VERSION/manifests/base/crds/$file" \
    || die "could not download $file"
  [[ "$(sha_of "$cache/$file.part")" == "$sum" ]] || { rm -f "$cache/$file.part"; die "checksum mismatch for $file"; }
  mv "$cache/$file.part" "$cache/$file"
done < "$here/crds.sha256"
# The CRDs are too large for client-side apply's last-applied annotation.
for f in $(awk '{print $2}' "$here/crds.sha256"); do
  kubectl apply --server-side --force-conflicts -f "$cache/$f" >/dev/null
done
# (kubectl wait fails with an accessor error while a new CRD has no status yet: poll instead)
crd_established() {
  local c
  for c in trainjobs trainingruntimes clustertrainingruntimes optimizationjobs; do
    [[ "$(kubectl get crd "$c.trainer.kubeflow.org" -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null)" == True ]] || return 1
  done
}
wait_until 90 crd_established || die "the Trainer CRDs were not established in time"

# --- controller, RBAC, webhook configurations (the controller generates its own serving
# certificate and writes the CA into the webhook configurations: no cert-manager). The Deployment in
# controller.yaml already has small requests, the sim-taint toleration and the keep-off-fake-nodes affinity.
kubectl apply --server-side --force-conflicts -f "$here/controller.yaml" >/dev/null
kubectl -n kubeflow-system rollout status deploy/kubeflow-trainer-controller-manager --timeout=300s >/dev/null

# The webhook serves with a self-generated certificate; wait until it answers.
# The probe object names no runtime, so the mutating webhook must be reached; its answer
# (accepted or rejected) shows the webhook is serving, a connection error does not.
probe_up() {
  local out
  out="$(kubectl create --dry-run=server -f - 2>&1 <<'YAML'
apiVersion: trainer.kubeflow.org/v1alpha1
kind: TrainJob
metadata:
  name: kdrill-webhook-probe
  namespace: default
spec:
  runtimeRef: {name: kdrill-webhook-probe}
YAML
)"
  [[ "$out" != *"failed calling webhook"* && "$out" != *"no endpoints"* && "$out" != *"connection refused"* && "$out" != *"x509"* && "$out" != *"i/o timeout"* && "$out" != *"context deadline"* ]]
}
wait_until 180 probe_up || die "the Trainer webhook did not become ready"
info "kubeflow-trainer ${TRAINER_VERSION} ready"
