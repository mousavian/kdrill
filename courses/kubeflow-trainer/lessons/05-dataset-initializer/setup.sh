source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
lesson_prep
trainer_cleanup
apply_labelled manifests/runtime.yaml
info "clustertrainingruntime/tiny-data has an initializer step; manifests/trainjob.yaml asks for a dataset"
