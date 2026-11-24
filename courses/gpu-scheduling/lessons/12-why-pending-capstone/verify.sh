source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
GPU='nvidia\.com/gpu'

echo "prod"
check_eq "chat: 2 replicas ready, on the L4 node" "2 yes" \
  "$(jp deploy/chat '{.status.readyReplicas}' -n prod) $(pods_on_nodes_with_ns prod app=chat nvidia.com/gpu.product=NVIDIA-L4 && echo yes)"
why "Start with: kubectl -n prod describe pod -l app=chat (Events at the bottom)"
check_eq "llm: ready on the H100 node with 8 GPUs" "1 yes 8" \
  "$(jp deploy/llm '{.status.readyReplicas}' -n prod) $(pods_on_nodes_with_ns prod app=llm nvidia.com/gpu.product=NVIDIA-H100-80GB-HBM3 && echo yes) $(res_limit nvidia.com/gpu deploy/llm prod)"
why "Start with: kubectl -n prod describe pod -l app=llm (Events at the bottom)"
check_eq "embed: 3 replicas ready, each on one nvidia.com/mig-1g.10gb slice" "3 1" \
  "$(jp deploy/embed '{.status.readyReplicas}' -n prod) $(res_limit nvidia.com/mig-1g.10gb deploy/embed prod)"
why "Start with: kubectl -n prod describe pod -l app=embed (Events at the bottom)"
vp="$(kubectl -n prod get pods -l app=vision --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
vdev="$( [[ -n "$vp" ]] && kubectl -n prod get resourceclaim "$(kubectl -n prod get pod "$vp" -o jsonpath='{.status.resourceClaimStatuses[0].resourceClaimName}')" -o jsonpath='{range .status.allocation.devices.results[*]}{.pool}/{.device} {end}' 2>/dev/null)"
check "vision: Running with an L40S allocated through DRA" bash -c '[[ "$1" =~ ^dra-1/l40s-[0-9]+\ $ ]]' _ "$vdev"
why "Start with: kubectl -n prod describe pod -l app=vision, then kubectl -n prod get resourceclaims -o yaml"
check_eq "vision still gets its GPU from template l40s-gpu (no nvidia.com/gpu)" "l40s-gpu" \
  "$(jp deploy/vision '{.spec.template.spec.resourceClaims[*].resourceClaimTemplateName}' -n prod)$(res_keys deploy/vision prod | grep -o 'nvidia.com/gpu' | head -1)"

echo "research"
check_eq "sweep: submitted to the team queue research-queue" research-queue "$(jp job/sweep '{.metadata.labels.kueue\.x-k8s\.io/queue-name}' -n research)"
check_eq "sweep: admitted by Kueue, both pods Running" "admitted 2" "$(wl_state research sweep) $(job_running sweep research)"
why "Start with: kubectl -n research get workloads, then kubectl -n research describe workload"
check_eq "notebook: 1 replica ready, on the L4 node" "1 yes" \
  "$(jp deploy/notebook '{.status.readyReplicas}' -n research) $(pods_on_nodes_with_ns research app=notebook nvidia.com/gpu.product=NVIDIA-L4 && echo yes)"
why "No pod at all? kubectl -n research describe rs -l app=notebook (Events at the bottom)"

echo "guards"
check_eq "Workload sizes unchanged (replicas chat 2, llm 1, embed 3, vision 1, notebook 1; sweep 2x1 GPU)" "2 1 3 1 1 2x1" \
  "$(jp deploy/chat '{.spec.replicas}' -n prod) $(jp deploy/llm '{.spec.replicas}' -n prod) $(jp deploy/embed '{.spec.replicas}' -n prod) $(jp deploy/vision '{.spec.replicas}' -n prod) $(jp deploy/notebook '{.spec.replicas}' -n research) $(jp job/sweep '{.spec.parallelism}' -n research)x$(jp job/sweep "{.spec.template.spec.containers[0].resources.limits.$GPU}" -n research)"
check_eq "GPU requests unchanged (chat 1, notebook 1)" "1 1" "$(res_limit nvidia.com/gpu deploy/chat prod) $(res_limit nvidia.com/gpu deploy/notebook research)"
check "No node has more GPUs booked than it has" no_gpu_overcommit nvidia.com/gpu
check_eq "Still 4 nodes" 4 "$(fake_node_count)"
check_fleet_unchanged capstone_config
why "Queues, flavors, quotas and the DeviceClass are shared infrastructure: fix the workloads instead."
