source "$KDRILL_HOME/courses/training-platform/lib.sh"
lesson_prep
apply_lesson manifests/pvc.yaml manifests/train.yaml
info "job/train is training 1200 steps (about 2 minutes); kdrill verify evicts its pod once"
