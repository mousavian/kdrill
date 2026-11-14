source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
gpu_node t4-1   t4   1
gpu_node t4-2   t4   1
gpu_node a10g-1 a10g 4
gpu_node l40s-1 l40s 4
gpu_node h100-1 h100 8 --cpu 192 --mem 2048Gi
fake_node cpu-1 --cpu 16 --mem 64Gi --label node.kubernetes.io/instance-type=m7i.4xlarge
wait_nodes_ready
baseline_save
apply_lesson manifests/etl.yaml manifests/whisper.yaml manifests/llm-serve.yaml
wait_running 30 2 app=whisper || true
