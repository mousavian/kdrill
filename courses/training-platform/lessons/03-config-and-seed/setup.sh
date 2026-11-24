source "$KDRILL_HOME/courses/training-platform/lib.sh"
lesson_prep
apply_lesson manifests/jobs.yaml
info "run-a and run-b started (about 30 s); compare their last log lines"
