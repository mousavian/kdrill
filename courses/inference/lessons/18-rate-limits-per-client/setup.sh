source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
# a model server that runs 2 requests at once; an answer takes about 0.7 s
sim_deploy llm --replicas 1 --seqs 2 --ttft 200ms --itl 50ms
apply_lesson manifests/gateway.yaml
lab_wait llm
gw_wait edge
# mallory: 8 users sending as fast as they can
load_up mallory 8 http://edge/v1/chat/completions -t 10 -w 14 -H "x-api-key: mallory"
kubectl rollout status deploy/mallory --timeout=120s >/dev/null
info "mallory's 8 users are saturating the model; alice (x-api-key: alice) is waiting in the queue"
