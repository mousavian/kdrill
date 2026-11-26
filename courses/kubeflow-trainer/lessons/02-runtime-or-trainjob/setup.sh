source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
lesson_prep
trainer_cleanup
apply_labelled manifests/platform-runtime.yaml
baseline_set platform "$(jp $CTR/tiny-gpt '{.spec}' | cksum | cut -d' ' -f1)"
info "clustertrainingruntime/tiny-gpt is the platform's; manifests/trainjob.yaml is the team's TrainJob"
