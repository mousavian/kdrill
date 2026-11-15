source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
apply_lesson manifests/llm.yaml
lab_wait llm
info "try it: kubectl exec client -- ask -n 30 -c 6 -t 20 -w 25 http://llm/v1/chat/completions   (and kubectl rollout restart deploy/llm in another terminal)"
