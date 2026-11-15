source "$KDRILL_HOME/courses/inference/lib.sh"
source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
for z in a b c; do
  gpu_node gpu-$z h100 4 --cpu 96 --mem 1024Gi --label "topology.kubernetes.io/zone=zone-$z"
done
wait_nodes_ready
fleet_settle
baseline_save
apply_lesson manifests/llm.yaml
wait_running_count app=llm 6 40
sleep 2
