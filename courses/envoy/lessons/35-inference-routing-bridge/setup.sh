source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
# Three "model servers" of one pool (stand-ins: they answer with their pod name),
# and an unrelated pod that must never be reachable through the llm route.
backend llama --replicas 3 --name llama-3-8b
backend admin --name admin
apply_lesson manifests/llm.yaml
lab_wait llama admin
gw_wait edge
