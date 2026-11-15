source "$KDRILL_HOME/courses/training/lib.sh"
lesson_prep
apply_lesson manifests/pvc.yaml manifests/train.yaml
info "job/train is training 1000 steps (about 1-2 minutes)"
