source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
lesson_prep
trainer_cleanup
kueue_cleanup
apply_lesson manifests/pvc.yaml
apply_labelled manifests/queues.yaml
apply_labelled manifests/runtime.yaml
baseline_set quota "$(jp clusterqueue.kueue.x-k8s.io/team-cq '{.spec.resourceGroups}')"
apply_lesson manifests/trainjob.yaml
baseline_set uid "$(jp $TJ/final-run '{.metadata.uid}')"
info "trainjob/final-run is running (kubectl get trainjob,pods,workloads); read what it does before fixing it"
