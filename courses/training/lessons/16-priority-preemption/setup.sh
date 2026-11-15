source "$KDRILL_HOME/courses/training/lib.sh"
lesson_prep
apply_labelled manifests/queues.yaml
baseline_set quota "$(jp clusterqueue.kueue.x-k8s.io/training-cq '{.spec.resourceGroups}')"
apply_lesson manifests/pretrain.yaml
info "pretrain (priority low) is admitted and training; manifests/urgent-eval.yaml is the urgent job"
