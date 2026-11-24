source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
gpu_node a10g-1 a10g 4
gpu_node a10g-2 a10g 4
wait_nodes_ready
baseline_save
kubectl -n team-a apply -f "$KDRILL_LESSON_DIR/manifests/sweep.yaml" >/dev/null
wait_running 40 8 app=sweep team-a || true
kubectl -n team-b apply -f "$KDRILL_LESSON_DIR/manifests/serve.yaml" >/dev/null
sleep 2
