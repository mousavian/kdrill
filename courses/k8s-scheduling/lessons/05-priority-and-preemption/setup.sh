fake_node node-1 --cpu 4 --mem 16Gi
fake_node node-2 --cpu 4 --mem 16Gi
wait_nodes_ready
apply_lesson manifests/batch.yaml
# Let batch fill the cluster first, then add the critical workload.
wait_until 40 test "$(running_count app=batch)" = 4 || true
apply_lesson manifests/critical.yaml
sleep 3
