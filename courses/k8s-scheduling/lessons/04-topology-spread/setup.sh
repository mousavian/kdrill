for z in a b c; do
  for i in 1 2; do
    fake_node "node-$z$i" --cpu 8 --mem 16Gi --label "topology.kubernetes.io/zone=$z"
  done
done
wait_nodes_ready
apply_lesson manifests/api.yaml
wait_running_count app=api 6 30
