source "$KDRILL_HOME/courses/training/lib.sh"
lesson_prep
apply_lesson manifests/pvc.yaml manifests/train.yaml manifests/sample.yaml
info "job/train is training (about 30 s); job/sample was started at the same time"
