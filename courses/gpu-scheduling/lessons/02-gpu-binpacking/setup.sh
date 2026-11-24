source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
gpu_node l40s-1 l40s 4
gpu_node l40s-2 l40s 4
gpu_node l40s-3 l40s 4
wait_nodes_ready
baseline_save
apply_lesson manifests/chat.yaml
wait_running 40 6 app=chat || true
apply_lesson manifests/finetune.yaml
sleep 2
