source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
lesson_prep
trainer_cleanup
apply_labelled manifests/runtime.yaml
apply_lesson manifests/explore.yaml manifests/urgent.yaml manifests/runaway.yaml
for t in explore urgent; do baseline_set "$t" "$(jp $TJ/$t '{.metadata.uid}')"; done
info "explore and runaway are running; urgent is created suspended (kubectl get trainjobs,pods)"
