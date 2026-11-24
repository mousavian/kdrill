source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
# 4 physical T4s, each advertised as 4 time-sliced replicas -> nvidia.com/gpu: 16
gpu_node t4-shared-1 t4 4 --shared 4
gpu_node a10g-1 a10g 4
gpu_node a10g-2 a10g 4
wait_nodes_ready
baseline_save
apply_lesson manifests/notebooks.yaml
wait_running 40 8 app=notebooks || true
apply_lesson manifests/trainer.yaml
wait_running 20 1 app=trainer || true
