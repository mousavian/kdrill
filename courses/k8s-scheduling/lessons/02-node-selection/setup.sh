fake_node node-1 --cpu 4 --mem 8Gi --label topology.kubernetes.io/zone=a --label disktype=ssd
fake_node node-2 --cpu 4 --mem 8Gi --label topology.kubernetes.io/zone=a --label disktype=hdd
fake_node node-3 --cpu 4 --mem 8Gi --label topology.kubernetes.io/zone=b --label disktype=ssd
fake_node node-4 --cpu 4 --mem 8Gi --label topology.kubernetes.io/zone=b --label disktype=hdd
wait_nodes_ready
apply_lesson manifests/db.yaml manifests/cache.yaml
wait_running_count 'app in (db,cache)' 4 30
