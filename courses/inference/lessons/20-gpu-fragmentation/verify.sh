source "$KDRILL_HOME/courses/inference/lib.sh"
source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
r8="$(jp deploy/llm-8b '{.spec.replicas}')"
_settled() { [[ "$(live_count Running app=llm-70b)" == 1 && "$(live_count Pending app=llm-8b)" == 0 && "$(live_count Running app=llm-8b)" == "$r8" ]]; }
[[ "${r8:-9}" -le 4 ]] && { wait_until 45 _settled || true; }   # a rollout reschedules the 8B pods, then the 70B pod can start
check_eq "llm-70b: its pod is Running" 1 "$(live_count Running app=llm-70b)"
why "kubectl describe pod -l app=llm-70b: '0/2 nodes are available: 2 Insufficient nvidia.com/gpu'. 4 GPUs must be free on ONE node."
check_eq "llm-8b: no pod is Pending" 0 "$(live_count Pending app=llm-8b)"
check_ge "llm-8b still serves with at least 4 replicas (now: ${r8:-?}; the fleet has room for exactly 4 next to the 70B)" 4 "${r8:-0}"
check_eq "llm-8b: all its replicas are Running" "$r8" "$(live_count Running app=llm-8b)"
check_eq "llm-70b still needs 4 GPUs per pod (tensor-parallel-size 4) and llm-8b 1" "4 1" "$(res_limit nvidia.com/gpu deploy/llm-70b) $(res_limit nvidia.com/gpu deploy/llm-8b)"
why "Do not shrink the model's GPU request: 70B weights do not fit in fewer GPUs."
n70="$(kubectl get pods -l app=llm-70b -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null)"
n8="$(kubectl get pods -l app=llm-8b -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' 2>/dev/null | sort -u | paste -sd' ' -)"
check "The 70B node (${n70:-none}) runs nothing else; the 8B replicas are on the other node (${n8:-none})" bash -c '[[ -n "$1" && -n "$2" && "$2" != *"$1"* ]]' _ "$n70" "$n8"
check "No node has more GPUs booked than it has" no_gpu_overcommit nvidia.com/gpu
check_eq "Still 2 nodes" 2 "$(fake_node_count)"
check_fleet_unchanged
