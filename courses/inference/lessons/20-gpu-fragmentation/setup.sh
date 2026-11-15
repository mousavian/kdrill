source "$KDRILL_HOME/courses/inference/lib.sh"
source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
gpu_node a100-1 a100 4 --cpu 96 --mem 1024Gi
gpu_node a100-2 a100 4 --cpu 96 --mem 1024Gi
wait_nodes_ready
fleet_settle
baseline_save
# the 8B replicas come first (as in real life: the small model was there before the big one arrived)
kubectl apply -f "$KDRILL_LESSON_DIR/manifests/models.yaml" -l app=llm-8b >/dev/null
wait_running_count app=llm-8b 6 40
kubectl apply -f "$KDRILL_LESSON_DIR/manifests/models.yaml" -l app=llm-70b >/dev/null
sleep 3
