source "$KDRILL_HOME/courses/inference/lib.sh"
apply_lesson manifests/inputs.yaml
info "the measured numbers are in the ConfigMap inputs: kubectl get cm inputs -o yaml"
