# Runs on `kdrill course stop training-platform`, before the components are removed.
# Lesson namespaces go with lesson cleanup; cluster-scoped Kueue objects that
# a training lesson left behind (label kdrill.dev/lesson=training-platform.*) go here.
for kind in clusterqueues.kueue.x-k8s.io resourceflavors.kueue.x-k8s.io workloadpriorityclasses.kueue.x-k8s.io; do
  for obj in $(kubectl get "$kind" -o jsonpath='{range .items[*]}{.metadata.name}={.metadata.labels.kdrill\.dev/lesson}{"\n"}{end}' 2>/dev/null \
               | awk -F= '$2 ~ /^training-platform\./ {print $1}'); do
    kubectl delete "$kind" "$obj" --ignore-not-found --timeout=60s >/dev/null 2>&1 || true
  done
done
info "training-platform course torn down"
