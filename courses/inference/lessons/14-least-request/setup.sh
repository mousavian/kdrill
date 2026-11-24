source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
sim_deploy llm --replicas 3 --seqs 16 --ttft 100ms --itl 20ms
apply_lesson manifests/gateway.yaml
lab_wait llm
gw_wait edge
# one replica is slow (a noisy neighbour, a thermally throttled GPU, a long prompt in front of it...)
slow="$(pod_names app=llm | awk '{print $1}')"
kubectl label pod "$slow" kdrill.dev/role=slow --overwrite >/dev/null
sim_admin "$(pod_ip "$slow")" '{"time-to-first-token":"3s"}'
info "pod $slow now needs 3 s to the first token"
