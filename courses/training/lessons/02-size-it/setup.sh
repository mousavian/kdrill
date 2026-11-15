source "$KDRILL_HOME/courses/training/lib.sh"
lesson_prep
apply_lesson manifests/job.yaml
info "job/train started; watch what happens to its pods: kubectl get pods -w"
