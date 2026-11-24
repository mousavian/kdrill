source "$KDRILL_HOME/courses/training-platform/lib.sh"
lesson_prep
apply_lesson manifests/workers-svc.yaml manifests/pvc.yaml manifests/ddp.yaml
info "job/ddp started (2 workers, checkpoints on PVC checkpoints); look at both pods"
