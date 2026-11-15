source "$KDRILL_HOME/courses/training/lib.sh"
lesson_prep
apply_lesson manifests/pvc.yaml manifests/sweep.yaml
info "job/sweep started: 3 runs, 2 at a time (about a minute)"
