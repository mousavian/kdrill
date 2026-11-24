# PriorityClass is cluster-scoped and is created by the learner.
kubectl delete priorityclass critical-priority --ignore-not-found >/dev/null
