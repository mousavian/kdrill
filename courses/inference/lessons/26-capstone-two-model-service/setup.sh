source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
sim_deploy summarize --model summarize --replicas 2 --seqs 4 --ttft 500ms --itl 30ms
epp_up chat
aggregator_up chat-pods
apply_lesson manifests/chat.yaml manifests/gateway.yaml
lab_wait summarize epp aggregator
gw_wait edge
info "the service is up but misbehaving in five ways; the chat pods are restarting"
