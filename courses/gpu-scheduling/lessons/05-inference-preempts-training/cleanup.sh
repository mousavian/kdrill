# The learner creates these cluster-scoped PriorityClasses.
kubectl delete priorityclass inference-critical eval-no-preempt --ignore-not-found >/dev/null
