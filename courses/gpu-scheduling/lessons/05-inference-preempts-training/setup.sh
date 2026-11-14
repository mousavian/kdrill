source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
gpu_node h100-1 h100 8 --cpu 192 --mem 2048Gi
gpu_node h100-2 h100 8 --cpu 192 --mem 2048Gi
wait_nodes_ready
apply_lesson manifests/training-low.yaml
baseline_save kubectl get priorityclass training-low -o jsonpath='{.value} {.preemptionPolicy} {.globalDefault}'
apply_lesson manifests/pretrain.yaml
wait_running 40 4 app=pretrain || true
apply_lesson manifests/chat-inference.yaml manifests/nightly-eval.yaml
sleep 3
