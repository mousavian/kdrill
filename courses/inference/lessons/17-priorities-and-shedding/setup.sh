source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
sim_deploy pool --replicas 2 --seqs 2 --ttft 100ms --itl 20ms
epp_up pool
apply_lesson manifests/gateway.yaml
lab_wait pool epp
gw_wait edge
# the pool is saturated: both replicas report a long queue and a nearly full KV cache
for ip in $(pod_ips app=pool); do
  sim_admin "$ip" '{"fake-metrics":{"running-requests":2,"waiting-requests":30,"kv-cache-usage":0.95}}'
done
info "both replicas are saturated (queue 30, KV cache 95%)"
