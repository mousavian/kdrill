source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
sim_deploy llm --seqs 2 --ttft 300ms --itl 100ms
aggregator_up llm-pods
apply_lesson manifests/scaledobject.yaml
lab_wait llm aggregator
load_up users 8 http://llm/v1/chat/completions -t 20 -w 25
kubectl rollout status deploy/users --timeout=120s >/dev/null
info "eight users are sending requests; KEDA needs ~30-40 s to react: kubectl get scaledobject,hpa -w"
