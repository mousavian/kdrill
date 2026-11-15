source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
# A model with a long time to first token (long prompt prefill) and a steady 100 ms per token.
sim_deploy llm --ttft 3s --itl 100ms --seqs 8
apply_lesson manifests/gateway.yaml
lab_wait llm
gw_wait edge
