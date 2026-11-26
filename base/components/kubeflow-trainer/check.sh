# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
kubectl -n kubeflow-system get deploy kubeflow-trainer-controller-manager >/dev/null
# a pod restarting right now is not a missing component: give it a minute
kubectl -n kubeflow-system wait deploy/kubeflow-trainer-controller-manager --for=condition=Available --timeout=60s >/dev/null
kubectl get crd trainjobs.trainer.kubeflow.org >/dev/null
