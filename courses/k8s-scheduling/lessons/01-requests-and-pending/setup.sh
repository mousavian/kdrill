fake_node node-a --cpu 4 --mem 8Gi
fake_node node-b --cpu 4 --mem 8Gi
wait_nodes_ready
apply_lesson manifests/web.yaml
# Give the scheduler a moment so the learner sees 2 Running + 1 Pending.
wait_until 30 test "$(running_count app=web)" = 2 || true
