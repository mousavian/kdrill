# Runs on `kdrill course stop kubeflow-trainer`, before the components are removed.
# TrainJobs and runtimes go first, while the Trainer controller still runs (it owns their JobSets);
# cluster-scoped Kueue objects a lesson left behind (label kdrill.dev/lesson=kubeflow-trainer.*) go here too.
source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
kubectl delete "$TJ" --all -A --ignore-not-found --timeout=90s >/dev/null 2>&1 || true
kubectl delete "$TR" --all -A --ignore-not-found --timeout=30s >/dev/null 2>&1 || true
kubectl delete "$CTR" --all --ignore-not-found --timeout=30s >/dev/null 2>&1 || true
for kind in clusterqueues.kueue.x-k8s.io resourceflavors.kueue.x-k8s.io workloadpriorityclasses.kueue.x-k8s.io; do
  for obj in $(kubectl get "$kind" -o jsonpath='{range .items[*]}{.metadata.name}={.metadata.labels.kdrill\.dev/lesson}{"\n"}{end}' 2>/dev/null \
               | awk -F= '$2 ~ /^kubeflow-trainer\./ {print $1}'); do
    kubectl delete "$kind" "$obj" --ignore-not-found --timeout=60s >/dev/null 2>&1 || true
  done
done
info "kubeflow-trainer course torn down"
