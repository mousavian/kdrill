source "$KDRILL_HOME/courses/inference/lib.sh"
source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
gpu_node h100-1 h100 8 --cpu 192 --mem 2048Gi
wait_nodes_ready
fleet_settle
baseline_save
kubectl apply -f "$KDRILL_LESSON_DIR/manifests/workloads.yaml" >/dev/null
wait_running_count app=finetune 2 30
wait_running_count app=chat 2 30
# the traffic burst: the autoscaler asks for a third chat replica
kubectl scale deploy/chat --replicas=3 >/dev/null
sleep 3
