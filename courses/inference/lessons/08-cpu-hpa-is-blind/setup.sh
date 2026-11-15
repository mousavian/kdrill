source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
# A server that runs 2 requests at once; its CPU request is the size of a "GPU-box host" slice.
sim_deploy llm --seqs 2 --ttft 300ms --itl 100ms --cpu 500m
aggregator_up llm-pods
apply_lesson manifests/hpa.yaml
lab_wait llm aggregator
load_up users 8 http://llm/v1/chat/completions -t 20 -w 25
kubectl rollout status deploy/users --timeout=120s >/dev/null
info "eight users are sending requests; the HPA needs ~30 s for its first CPU reading: kubectl get hpa -w"
