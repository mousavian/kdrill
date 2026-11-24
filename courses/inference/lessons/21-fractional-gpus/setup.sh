source "$KDRILL_HOME/courses/inference/lib.sh"
source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
gpu_node whole-1 h100 2 --cpu 64 --mem 512Gi
# an 80 GB A100 cut into seven 10 GB slices, and a 40 GB A100 cut into seven 5 GB slices
gpu_node mig-80 a100 1 --cpu 32 --mem 256Gi --mig 1g.10gb=7
gpu_node mig-40 a100 1 --cpu 32 --mem 256Gi --mig 1g.5gb=7
wait_nodes_ready
fleet_settle
baseline_save
# chat first (it takes the two whole GPUs), then the embedding replicas that cannot find a GPU
kubectl apply -f "$KDRILL_LESSON_DIR/manifests/models.yaml" -l app=chat >/dev/null
wait_running_count app=chat 2 40
kubectl apply -f "$KDRILL_LESSON_DIR/manifests/models.yaml" -l app=embed >/dev/null
sleep 3
