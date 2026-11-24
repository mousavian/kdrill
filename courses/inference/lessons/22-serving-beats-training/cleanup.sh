# The learner creates cluster-scoped PriorityClasses (names of their choice): remove every
# one that is not a built-in system-* class.
kubectl get priorityclass -o name 2>/dev/null | grep -v '/system-' | xargs kubectl delete --ignore-not-found --wait=false >/dev/null 2>&1 || true
