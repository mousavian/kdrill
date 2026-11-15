source "$KDRILL_HOME/courses/inference/lib.sh"
source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
gpu_node main-1 h100 4 --cpu 96 --mem 1024Gi
# spare pool: 2 GPUs kept for surges and node-draining, tainted so that normal workloads stay away
gpu_node spare-1 h100 2 --cpu 48 --mem 512Gi --label pool=spare --taint capacity=spare:NoSchedule
wait_nodes_ready
fleet_settle
baseline_save
apply_lesson manifests/llm.yaml
wait_running_count app=llm 4 40
