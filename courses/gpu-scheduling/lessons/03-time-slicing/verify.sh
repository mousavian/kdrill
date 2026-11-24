source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
KEY=nvidia.com/gpu.sharing-strategy

check_eq "notebooks: 8 replicas, all ready" 8 "$(jp deploy/notebooks '{.status.readyReplicas}')"
check "every notebook pod runs on a time-sliced node" pods_on_nodes_with app=notebooks "$KEY=time-slicing"
why "kubectl get pods -o wide -l app=notebooks. Notebooks are idle most of the time; give them GPU slices, not whole GPUs."
check "notebooks have a required node rule on $KEY" bash -c '[[ " $1 " == *" '"$KEY"' "* ]]' _ "$(required_affinity_keys deploy/notebooks)"
why "Add a nodeSelector or required node affinity: $KEY = time-slicing."

check_eq "trainer: its pod is Running" 1 "$(jp deploy/trainer '{.status.readyReplicas}')"
check "trainer runs on exclusive (non-shared) GPUs" pods_on_nodes_with app=trainer "$KEY=none"
why "Right now 'nvidia.com/gpu: 4' on t4-shared-1 can mean 4 slices of ONE physical T4. kubectl get pod -l app=trainer -o wide"
check "trainer has a required node rule on $KEY" bash -c '[[ " $1 " == *" '"$KEY"' "* ]]' _ "$(required_affinity_keys deploy/trainer)"
why "e.g. required node affinity {key: $KEY, operator: NotIn, values: [time-slicing]} (or In [none])."

check_eq "Replica counts unchanged (notebooks 8, trainer 1)" "8 1" "$(jp deploy/notebooks '{.spec.replicas}') $(jp deploy/trainer '{.spec.replicas}')"
check_eq "GPU requests unchanged (notebooks 1, trainer 4)" "1 4" "$(res_limit nvidia.com/gpu deploy/notebooks) $(res_limit nvidia.com/gpu deploy/trainer)"
check_eq "Still 3 nodes" 3 "$(fake_node_count)"
check_fleet_unchanged
