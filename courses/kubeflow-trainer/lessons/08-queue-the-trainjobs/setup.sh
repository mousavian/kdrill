source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
lesson_prep
trainer_cleanup
kueue_cleanup
apply_labelled manifests/runtime.yaml
apply_labelled manifests/queues.yaml
baseline_set quota "$(jp clusterqueue.kueue.x-k8s.io/training-cq '{.spec.resourceGroups}')"
apply_lesson manifests/trainjobs.yaml
info "exp-a and exp-b are running side by side, outside the queue"
