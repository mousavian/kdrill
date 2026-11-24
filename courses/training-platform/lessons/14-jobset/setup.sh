source "$KDRILL_HOME/courses/training-platform/lib.sh"
lesson_prep
apply_lesson manifests/pvc.yaml manifests/jobset.yaml
info "jobset/ddp created; kubectl get jobset,jobs,pods"
