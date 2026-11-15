source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
sim_deploy small --model small --replicas 2 --ttft 100ms --itl 20ms
sim_deploy large --model large --replicas 1 --ttft 400ms --itl 50ms
apply_lesson manifests/gateway.yaml
lab_wait small large
gw_wait edge
