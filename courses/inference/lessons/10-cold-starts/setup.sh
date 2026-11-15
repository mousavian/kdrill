source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
aggregator_up llm-pods
apply_lesson manifests/llm.yaml
lab_wait aggregator
info "llm is scaled to zero: a request now finds no server at all"
