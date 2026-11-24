source "$KDRILL_HOME/courses/training-platform/lib.sh"
lesson_prep
apply_lesson manifests/workers-svc.yaml manifests/pvc.yaml manifests/ddp.yaml
info "job/ddp started (2 workers, 1500 steps, about 1-2 minutes); kdrill verify evicts one worker once"
