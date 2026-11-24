source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
apply_lesson manifests/llm.yaml
lab_wait llm
# three users, always one request each in flight, 24 tokens per answer
load_up users 3 http://llm/v1/chat/completions -t 24 -p "Write a short story about a robot."
kubectl rollout status deploy/users --timeout=120s >/dev/null
info "three users are now sending requests to a server with ONE slot"
