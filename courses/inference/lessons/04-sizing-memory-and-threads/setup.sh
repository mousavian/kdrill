source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
apply_lesson manifests/llm.yaml
kubectl wait pod/client --for=condition=Ready --timeout=180s >/dev/null || die "the client pod did not start"
info "the server is being OOMKilled on purpose: kubectl describe pod -l app=llm"
