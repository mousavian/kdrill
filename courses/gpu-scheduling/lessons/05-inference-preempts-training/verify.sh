source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
SPEC='{.spec.template.spec'

ic="$(jp priorityclass/inference-critical '{.value}')"
ev="$(jp priorityclass/eval-no-preempt '{.value}')"
check "PriorityClass inference-critical exists with a value above training-low (1000)" bash -c '[[ "$1" =~ ^-?[0-9]+$ ]] && (( $1 > 1000 ))' _ "$ic"
why "kubectl create priorityclass inference-critical --value=100000"
check "inference-critical: not globalDefault, default preemptionPolicy (PreemptLowerPriority)" bash -c \
  '[[ -n "$3" && "$1" != true && ( -z "$2" || "$2" == PreemptLowerPriority ) ]]' _ \
  "$(jp priorityclass/inference-critical '{.globalDefault}')" "$(jp priorityclass/inference-critical '{.preemptionPolicy}')" "$ic"
check "PriorityClass eval-no-preempt exists with a value between training-low and inference-critical" \
  bash -c '[[ "$1" =~ ^-?[0-9]+$ && "$2" =~ ^-?[0-9]+$ ]] && (( $1 > 1000 && $1 < $2 ))' _ "$ev" "$ic"
why "Eval should be scheduled before training, but after inference."
check_eq "eval-no-preempt has preemptionPolicy Never" Never "$(jp priorityclass/eval-no-preempt '{.preemptionPolicy}')"
why "kubectl create priorityclass eval-no-preempt --value=5000 --preemption-policy=Never"
check "eval-no-preempt is not globalDefault" bash -c '[[ -n "$2" && "$1" != true ]]' _ "$(jp priorityclass/eval-no-preempt '{.globalDefault}')" "$ev"

check_eq "chat-inference uses priorityClassName inference-critical" inference-critical "$(jp deploy/chat-inference "$SPEC.priorityClassName}")"
check_eq "chat-inference: 2 replicas, both ready" 2 "$(jp deploy/chat-inference '{.status.readyReplicas}')"
why "Pods keep the priority they were created with; changing the template rolls new pods, which can preempt."

check_eq "nightly-eval uses priorityClassName eval-no-preempt" eval-no-preempt "$(jp deploy/nightly-eval "$SPEC.priorityClassName}")"
pp="$(kubectl get pods -l app=nightly-eval -o jsonpath='{range .items[*]}{.spec.preemptionPolicy}/{.spec.priority}{"\n"}{end}' 2>/dev/null | sort -u | paste -sd' ' -)"
check "the nightly-eval pod carries preemptionPolicy Never and a priority above 1000" bash -c '[[ "$1" == Never/* && "$1" != *" "* ]] && (( ${1#Never/} > 1000 ))' _ "$pp"
why "The pod gets priority and preemptionPolicy from its class at creation; recreate the pod after creating the class."
check_eq "nightly-eval is waiting (Pending): it may not evict training" 1 "$(live_count Pending app=nightly-eval)"
why "If eval is Running, it pushed out a training pod; preemptionPolicy Never must stop that."

check_eq "pretrain still has spec.replicas 4 and priorityClassName training-low" "4 training-low" \
  "$(jp deploy/pretrain '{.spec.replicas}') $(jp deploy/pretrain "$SPEC.priorityClassName}")"
check_eq "pretrain: exactly 2 pods Running (2 were preempted by inference)" 2 "$(live_count Running app=pretrain)"
check_eq "pretrain: 2 pods Pending, waiting for GPUs" 2 "$(live_count Pending app=pretrain)"
why "Don't delete or scale training; preemption should make the room."
check_eq "All three Deployments still ask for 4 GPUs per pod" "4 4 4" \
  "$(res_limit nvidia.com/gpu deploy/pretrain) $(res_limit nvidia.com/gpu deploy/chat-inference) $(res_limit nvidia.com/gpu deploy/nightly-eval)"
check_eq "Still 2 nodes" 2 "$(fake_node_count)"
check_fleet_unchanged kubectl get priorityclass training-low -o jsonpath='{.value} {.preemptionPolicy} {.globalDefault}'
