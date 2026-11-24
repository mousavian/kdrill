GPU='nvidia\.com/gpu'
C='{.spec.template.spec.containers[0].resources'

check_eq "llm container limits nvidia.com/gpu = 2" 2 "$(jp deploy/llm "$C.limits.$GPU}")"
why "Extended resources go in resources.limits (requests, if given, must be equal). Whole numbers only."
req="$(jp deploy/llm "$C.requests.$GPU}")"
check "GPU request, if set, equals the limit (2)" bash -c '[[ -z "$1" || "$1" == 2 ]]' _ "$req"
why "For extended resources requests and limits must be identical; simplest is to set only the limit."

check_eq "llm still has 3 replicas" 3 "$(jp deploy/llm '{.spec.replicas}')"
check_eq "llm: 3 pods ready" 3 "$(jp deploy/llm '{.status.readyReplicas}')"
why "Pending pods? kubectl describe pod: look for 'untolerated taint' and 'Insufficient nvidia.com/gpu'."
check "All llm pods are Running on GPU nodes" pods_on_nodes_with app=llm nvidia.com/gpu.present=true
why "kubectl get pods -o wide -l app=llm — pods must be on gpu-1 / gpu-2."

check_eq "llm tolerates the nvidia.com/gpu taint" nvidia.com/gpu "$(jp deploy/llm '{.spec.template.spec.tolerations[?(@.key=="nvidia.com/gpu")].key}')"
why "GPU nodes are tainted nvidia.com/gpu=present:NoSchedule. Add a toleration with key nvidia.com/gpu."

for n in gpu-1 gpu-2; do
  check_eq "$n is still tainted nvidia.com/gpu=present:NoSchedule" "present:NoSchedule" \
    "$(jp node/$n '{.spec.taints[?(@.key=="nvidia.com/gpu")].value}'):$(jp node/$n '{.spec.taints[?(@.key=="nvidia.com/gpu")].effect}')"
  why "Keep the taint: it stops CPU-only workloads from wasting GPU nodes. Tolerate it instead."
  check_eq "$n still has capacity nvidia.com/gpu = 4" 4 "$(jp node/$n "{.status.capacity.$GPU}")"
  why "Node capacity is hardware; don't edit it."
done
for n in cpu-1 cpu-2; do
  g="$(jp node/$n "{.status.capacity.$GPU}")"
  check "$n has no GPU capacity" bash -c '[[ -z "$1" || "$1" == 0 ]]' _ "$g"
  why "Giving CPU nodes fake GPUs is cheating. The pods must run where the GPUs are."
done
check_eq "There are still exactly 4 worker nodes" 4 "$(kubectl get nodes -l type=kwok --no-headers 2>/dev/null | wc -l | tr -d ' ')"
