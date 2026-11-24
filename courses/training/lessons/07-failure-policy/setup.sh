source "$KDRILL_HOME/courses/training/lib.sh"
lesson_prep
apply_lesson manifests/jobs.yaml
info "buggy and steady started; watch: kubectl get jobs,pods -w"
