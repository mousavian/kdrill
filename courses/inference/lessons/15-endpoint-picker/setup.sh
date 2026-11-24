source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
sim_deploy llm --replicas 3 --seqs 4 --ttft 100ms --itl 20ms
epp_up llm
apply_lesson manifests/gateway.yaml
lab_wait llm epp
gw_wait edge
# one replica is saturated: 4 running, 40 waiting, KV cache 90% full (the simulator's admin knobs)
busy="$(pod_names app=llm | awk '{print $1}')"
kubectl label pod "$busy" kdrill.dev/role=busy --overwrite >/dev/null
sim_admin "$(pod_ip "$busy")" '{"fake-metrics":{"running-requests":4,"waiting-requests":40,"kv-cache-usage":0.9}}'
info "pod $busy reports a full queue; the endpoint picker (deploy/epp) is running but the gateway does not use it yet"
