source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"

check_eq "finetune: its 4-GPU pod is Running" 1 "$(jp deploy/finetune '{.status.readyReplicas}')"
why "kubectl describe pod -l app=finetune: '3 Insufficient nvidia.com/gpu' although 6 GPUs are free. Where are the chat pods? kubectl get pods -o wide"
check_eq "finetune still asks for 4 GPUs in one pod" 4 "$(res_limit nvidia.com/gpu deploy/finetune)"

check_eq "chat: 6 replicas, all ready" 6 "$(jp deploy/chat '{.status.readyReplicas}')"
check_eq "chat still has spec.replicas 6" 6 "$(jp deploy/chat '{.spec.replicas}')"
check_eq "chat still asks for 1 GPU per pod" 1 "$(res_limit nvidia.com/gpu deploy/chat)"
check_eq "chat pods use schedulerName gpu-binpack" gpu-binpack "$(jp deploy/chat '{.spec.template.spec.schedulerName}')"
why "Set spec.template.spec.schedulerName: gpu-binpack. That scheduler scores nodes with MostAllocated on nvidia.com/gpu."
sched="$(kubectl get pods -l app=chat -o jsonpath='{range .items[*]}{.spec.schedulerName}{"\n"}{end}' 2>/dev/null | sort -u | paste -sd' ' -)"
check_eq "every running chat pod was placed by gpu-binpack" gpu-binpack "$sched"
check_eq "chat is not pinned with nodeName, nodeSelector or node affinity" "" \
  "$(jp deploy/chat '{.spec.template.spec.nodeName}{.spec.template.spec.nodeSelector}{.spec.template.spec.affinity.nodeAffinity}')"
why "Hand-placing pods doesn't survive the next rollout. Let the scheduler profile pack them."

check "No node has more GPUs booked than it has" no_gpu_overcommit nvidia.com/gpu
check_eq "Still 3 nodes" 3 "$(fake_node_count)"
check_fleet_unchanged
