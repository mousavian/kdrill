source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
apply_lesson manifests/llm.yaml
lab_wait llm
info "try: kubectl exec client -- ask -v -n 4 -c 4 -t 48 http://llm/v1/chat/completions   (the 4 users start together; compare the last time column)"
