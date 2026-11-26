source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
lesson_prep
trainer_cleanup
apply_lesson manifests/pvc.yaml
apply_labelled manifests/runtime.yaml
apply_lesson manifests/trainjob.yaml
baseline_set uid "$(jp $TJ/flaky '{.metadata.uid}')"
info "trainjob/flaky is running and will crash at step 300 (kubectl get trainjob,jobset,pods)"
