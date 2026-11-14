source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
gpu_node mixed-1 l40s 4 --dra --label node.kubernetes.io/instance-type=custom-l4-l40s
gpu_node h100-1  h100 4 --dra --cpu 96 --mem 1024Gi
wait_nodes_ready
dra_slice mixed-1 l4 2 l40s 2
dra_slice h100-1 h100 4
gpu_device_class
baseline_save kubectl get deviceclass gpu.nvidia.com -o jsonpath='{.spec}'
apply_lesson manifests/templates.yaml
apply_lesson manifests/llm.yaml manifests/trainer.yaml manifests/encoder-decoder.yaml
wait_running 30 4 'app in (llm,trainer,encoder,decoder)' || true
