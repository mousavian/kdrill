source "$KDRILL_HOME/courses/inference/lib.sh"
source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
keys="$(res_keys deploy/embed)"
check_eq "embed requests a MIG slice of 10 GB: nvidia.com/mig-1g.10gb: 1" "1" "$(jp deploy/embed '{.spec.template.spec.containers[0].resources.limits.nvidia\.com/mig-1g\.10gb}')"
why "The model needs ~9 GB (annotation kdrill.dev/model-gpu-memory). A 5 GB slice would schedule fine and then run out of memory: pick the smallest slice that FITS."
check "embed no longer asks for a whole GPU (nvidia.com/gpu)" bash -c '[[ "$1" != *"nvidia.com/gpu"* ]]' _ "$keys"
_embed_up() { [[ "$(live_count Running app=embed)" == 6 ]]; }
[[ "$(jp deploy/embed '{.spec.template.spec.containers[0].resources.limits.nvidia\.com/mig-1g\.10gb}')" == 1 ]] && { wait_until 40 _embed_up || true; }
check_eq "embed: all 6 replicas Running" 6 "$(live_count Running app=embed)"
why "kubectl describe pod -l app=embed: Insufficient nvidia.com/mig-... shows which resource ran out."
check "embed pods all run on the 80 GB MIG node (mig-80), not on the 5 GB slices" pods_on_nodes_with app=embed kubernetes.io/hostname=mig-80
check_eq "chat: 2 replicas Running on the whole-GPU node" 2 "$(live_count Running app=chat)"
check "chat pods are on whole-1" pods_on_nodes_with app=chat kubernetes.io/hostname=whole-1
check_eq "chat still asks for one whole GPU and 2 replicas" "1 2" "$(res_limit nvidia.com/gpu deploy/chat) $(jp deploy/chat '{.spec.replicas}')"
check_eq "embed still has 6 replicas" 6 "$(jp deploy/embed '{.spec.replicas}')"
_no_over() { no_gpu_overcommit nvidia.com/gpu && no_gpu_overcommit nvidia.com/mig-1g.10gb && no_gpu_overcommit nvidia.com/mig-1g.5gb; }
check "No node has more GPUs (or slices) booked than it has" _no_over
check_eq "Still 3 nodes" 3 "$(fake_node_count)"
check_fleet_unchanged
