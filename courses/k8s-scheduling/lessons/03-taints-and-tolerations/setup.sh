fake_node general-1 --cpu 4 --mem 16Gi --label pool=general
fake_node general-2 --cpu 4 --mem 16Gi --label pool=general
fake_node ml-1 --cpu 8 --mem 32Gi --label pool=ml --taint dedicated=ml:NoSchedule
fake_node ml-2 --cpu 8 --mem 32Gi --label pool=ml --taint dedicated=ml:NoSchedule
wait_nodes_ready
apply_lesson manifests/web.yaml
wait_until 30 test "$(running_count app=web)" = 2 || true
apply_lesson manifests/trainer.yaml
sleep 3
