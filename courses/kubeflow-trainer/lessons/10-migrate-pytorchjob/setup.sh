source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
lesson_prep
trainer_cleanup
apply_labelled manifests/runtime.yaml
baseline_set platform "$(jp $CTR/tiny-ddp '{.spec}' | cksum | cut -d' ' -f1)"
info "manifests/pytorchjob.yaml is the legacy manifest (not applicable here); the runtime tiny-ddp is ready"
