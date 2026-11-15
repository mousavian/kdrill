source "$KDRILL_HOME/courses/training/lib.sh"
lesson_prep
apply_lesson manifests/pvc.yaml manifests/ddp.yaml
info "job/ddp started: 2 workers; read their logs"
