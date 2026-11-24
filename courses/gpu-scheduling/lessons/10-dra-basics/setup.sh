source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
# DRA nodes: no nvidia.com/gpu extended resource; GPUs are published as devices.
gpu_node l40s-1 l40s 4 --dra
gpu_node l40s-2 l40s 4 --dra
wait_nodes_ready
dra_slice l40s-1 l40s 4
dra_slice l40s-2 l40s 4
baseline_save
apply_lesson manifests/vllm.yaml
