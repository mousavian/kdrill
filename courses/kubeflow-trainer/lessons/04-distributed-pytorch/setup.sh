source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
lesson_prep
trainer_cleanup
apply_labelled manifests/runtime.yaml
apply_lesson manifests/trainjob.yaml
info "trainjob/ddp has two nodes, and both train on their own (about 25 s)"
