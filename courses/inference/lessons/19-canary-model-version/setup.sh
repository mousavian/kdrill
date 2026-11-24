source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
sim_deploy v1 --replicas 2 --ttft 100ms --itl 20ms
sim_deploy v2 --replicas 1 --ttft 100ms --itl 20ms
apply_lesson manifests/gateway.yaml
lab_wait v1 v2
gw_wait edge
