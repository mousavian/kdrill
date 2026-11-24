source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
# three Deployments of one pool: the adapters are loaded per replica (a startup argument)
sim_deploy adapter-sql  --model base-model --lora sql-lora  --labels pool=llm --no-service --seqs 4
sim_deploy adapter-chat --model base-model --lora chat-lora --labels pool=llm --no-service --seqs 4
sim_deploy plain        --model base-model                  --labels pool=llm --no-service --seqs 4
epp_up llm --selector pool=llm
apply_lesson manifests/gateway.yaml
lab_wait adapter-sql adapter-chat plain epp
gw_wait edge
# the replicas publish which adapters they have loaded (vllm:lora_requests_info); the simulator only does so after
# a first adapter request, so publish it from the start
now="$(date +%s)"
pub() { sim_admin "$(pod_ip "$(pod_names app=$1 | awk '{print $1}')")" "{\"fake-metrics\":{\"running-requests\":0,\"waiting-requests\":0,\"kv-cache-usage\":0.1,\"loras\":[{\"running\":\"$2\",\"waiting\":\"\",\"timestamp\":$now}]}}"; }
pub adapter-sql sql-lora
pub adapter-chat chat-lora
sim_admin "$(pod_ip "$(pod_names app=plain | awk '{print $1}')")" '{"fake-metrics":{"running-requests":0,"waiting-requests":0,"kv-cache-usage":0.1}}'
