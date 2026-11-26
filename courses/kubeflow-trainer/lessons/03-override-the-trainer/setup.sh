source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
lesson_prep
trainer_cleanup
apply_labelled manifests/runtime.yaml
baseline_set platform "$(jp $CTR/tiny-gpt '{.spec}' | cksum | cut -d' ' -f1)"
apply_lesson manifests/trainjob.yaml
info "trainjob/tuned is running; it was meant to train 300 steps (about 60 s of wrong work if left alone)"
