# Remove Kubeflow Trainer completely. Order: custom resources (while the controller still runs,
# it owns their finalizers and JobSets) -> controller -> webhook configurations -> CRDs.
# The webhook configurations are removed explicitly before the CRDs: with failurePolicy Fail and
# no controller behind them they would block every TrainJob/runtime request (and namespace cleanup).
set +e
TRAINER_VERSION="${TRAINER_VERSION:-v2.4.0}"
for k in trainjobs.trainer.kubeflow.org trainingruntimes.trainer.kubeflow.org optimizationjobs.trainer.kubeflow.org; do
  kubectl delete "$k" --all -A --ignore-not-found --timeout=60s >/dev/null 2>&1
done
kubectl delete clustertrainingruntimes.trainer.kubeflow.org --all --ignore-not-found --timeout=60s >/dev/null 2>&1
# Anything still stuck on a finalizer (the controller is about to go): clear them.
for k in trainjobs.trainer.kubeflow.org trainingruntimes.trainer.kubeflow.org optimizationjobs.trainer.kubeflow.org; do
  for o in $(kubectl get "$k" -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null); do
    kubectl patch "$k" "${o#*/}" -n "${o%/*}" --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1
  done
done
for o in $(kubectl get clustertrainingruntimes.trainer.kubeflow.org -o name 2>/dev/null); do
  kubectl patch "$o" --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1
done
kubectl delete deploy kubeflow-trainer-controller-manager -n kubeflow-system --ignore-not-found --timeout=60s >/dev/null 2>&1
kubectl delete mutatingwebhookconfiguration defaulter.trainer.kubeflow.org --ignore-not-found >/dev/null 2>&1
kubectl delete validatingwebhookconfiguration validator.trainer.kubeflow.org --ignore-not-found >/dev/null 2>&1
kubectl delete -f "$KDRILL_HOME/base/components/kubeflow-trainer/controller.yaml" --ignore-not-found --wait=false >/dev/null 2>&1
kubectl delete crd trainjobs.trainer.kubeflow.org trainingruntimes.trainer.kubeflow.org \
  clustertrainingruntimes.trainer.kubeflow.org optimizationjobs.trainer.kubeflow.org --ignore-not-found --timeout=90s >/dev/null 2>&1
kubectl delete ns kubeflow-system --ignore-not-found --timeout=120s >/dev/null 2>&1
info "kubeflow-trainer removed"
