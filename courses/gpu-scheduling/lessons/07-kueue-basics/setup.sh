source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
gpu_node a100-1 a100 8 --cpu 96 --mem 1024Gi
gpu_node a100-2 a100 8 --cpu 96 --mem 1024Gi
gpu_node t4-1   t4   4
wait_nodes_ready
baseline_save
apply_lesson manifests/jobs.yaml
