source "$KDRILL_HOME/courses/inference/lib.sh"
source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
S='{.spec.template.spec'
cs="$(jp deploy/chat "$S.priorityClassName}")"; ts="$(jp deploy/finetune "$S.priorityClassName}")"
cv="$(jp priorityclass/${cs:-none} '{.value}')"; tv="$(jp priorityclass/${ts:-none} '{.value}')"
check "chat has a PriorityClass (${cs:-none}, value ${cv:-?}) higher than finetune's (${ts:-none}, value ${tv:-?})" bash -c '[[ "$1" =~ ^-?[0-9]+$ && "$2" =~ ^-?[0-9]+$ ]] && (( $1 > $2 ))' _ "${cv:-x}" "${tv:-x}"
why "kubectl create priorityclass serving --value=100000; set priorityClassName in both pod templates (training: a lower value, e.g. 1000)."
check "Neither class is the cluster default (globalDefault would change every other pod)" bash -c '[[ -n "$1" && -n "$2" && "$(kubectl get priorityclass "$1" -o jsonpath="{.globalDefault}")" != true && "$(kubectl get priorityclass "$2" -o jsonpath="{.globalDefault}")" != true ]]' _ "$cs" "$ts"
_settled() { [[ "$(live_count Running app=chat)" == 3 && "$(live_count Running app=finetune)" == 1 && "$(live_count Pending app=finetune)" == 1 ]]; }
[[ -n "$cs" && -n "$ts" && "${cv:-0}" -gt "${tv:-0}" ]] 2>/dev/null && { wait_until 45 _settled || true; }   # the Deployments roll their pods, then preemption happens
check_eq "chat: 3 replicas, all Running" 3 "$(live_count Running app=chat)"
why "Pods keep the priority they had at creation. The Pending chat pod preempts only after it has a higher priority than a running pod: recreate pods after creating the classes (a change to the template rolls them)."
check_eq "finetune: one pod Running and one Pending (it was preempted and waits for a GPU)" "1 1" "$(live_count Running app=finetune) $(live_count Pending app=finetune)"
pre="$(kubectl get events --field-selector reason=Preempted -o jsonpath='{range .items[*]}{.involvedObject.name}{"\n"}{end}' 2>/dev/null | grep -c '^finetune-' || true)"
check_ge "The scheduler recorded the preemption of a finetune pod (Preempted events: ${pre:-0})" 1 "${pre:-0}"
why "kubectl get events --field-selector reason=Preempted"
check_eq "Replica counts and GPU requests unchanged (chat 3 x 2 GPUs, finetune 2 x 2 GPUs)" "3 2 2 2" "$(jp deploy/chat '{.spec.replicas}') $(jp deploy/finetune '{.spec.replicas}') $(res_limit nvidia.com/gpu deploy/chat) $(res_limit nvidia.com/gpu deploy/finetune)"
check "No node has more GPUs booked than it has" no_gpu_overcommit nvidia.com/gpu
check_eq "Still 1 node" 1 "$(fake_node_count)"
check_fleet_unchanged
