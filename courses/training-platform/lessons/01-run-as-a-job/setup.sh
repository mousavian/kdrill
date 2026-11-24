source "$KDRILL_HOME/courses/training-platform/lib.sh"
lesson_prep
apply_lesson manifests/deployment.yaml
info "deployment/train is training (about 30 s), and will then be restarted forever"
