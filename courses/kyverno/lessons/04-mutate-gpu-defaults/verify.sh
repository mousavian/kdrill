source "$KDRILL_HOME/courses/kyverno/lib.sh"
NS=ml-team
T='{.spec.tolerations[*].key}'
count() { tr ' ' '\n' | grep -cx "$1"; }
kyv_settle

check "ClusterPolicy gpu-defaults exists and is Ready" policy_ready gpu-defaults

echo "mutation (server-side dry-run of probes/)"
tol="$(dr_get gpu-pod.yaml "$T")"
check_eq "GPU Pod: gets the nvidia.com/gpu toleration once" 1 "$(echo "$tol" | count nvidia.com/gpu)"
check_eq "GPU Pod: keeps its own 'dedicated' toleration" 1 "$(echo "$tol" | count dedicated)"
why "patchStrategicMerge replaces lists that have no merge key (tolerations is one). Append with a JSON patch: op add, path /spec/tolerations/-"
check_eq "GPU Pod without a GPU type: nodeSelector nvidia.com/gpu.product=NVIDIA-L4" NVIDIA-L4 \
  "$(dr_get gpu-pod.yaml '{.spec.nodeSelector.nvidia\.com/gpu\.product}')"
check_eq "GPU Pod that already tolerates nvidia.com/gpu: no duplicate toleration" 1 "$(dr_get gpu-pod-h100.yaml "$T" | count nvidia.com/gpu)"
why "A JSON patch append runs every time. Add a precondition: no toleration with key nvidia.com/gpu yet."
check_eq "GPU Pod that chose H100: keeps H100 and its zone selector" "NVIDIA-H100-80GB-HBM3 us-east-1a" \
  "$(dr_get gpu-pod-h100.yaml '{.spec.nodeSelector.nvidia\.com/gpu\.product} {.spec.nodeSelector.topology\.kubernetes\.io/zone}')"
why "+(key): value only adds the key when it is absent."
check_eq "GPU requested by the 2nd container: still mutated" "1 NVIDIA-L4" \
  "$(dr_get gpu-sidecar.yaml "$T" | count nvidia.com/gpu) $(dr_get gpu-sidecar.yaml '{.spec.nodeSelector.nvidia\.com/gpu\.product}')"
cpu="$(dr_get cpu-pod.yaml "$T") $(dr_get cpu-pod.yaml '{.spec.nodeSelector}')"
check "CPU-only Pod: no GPU toleration, no GPU nodeSelector" bash -c '[[ "$1" != *nvidia* && "$1" == *linux* ]]' _ "$cpu"
why "Use preconditions: only Pods where some container has limits.nvidia.com/gpu."

echo "workloads"
check_eq "web: 2 ready, on CPU workers" "2 yes" "$(jp deploy/web '{.status.readyReplicas}' -n $NS) $(pods_on_nodes_with app=web '!nvidia.com/gpu.present' && echo yes)"
why "Running Pods keep the mutations they got at creation: restart the Deployments after fixing the policy (kubectl rollout restart deploy -n $NS)."
check_eq "chat: 2 ready, on the L4 node" "2 yes" "$(jp deploy/chat '{.status.readyReplicas}' -n $NS) $(pods_on_nodes_with app=chat nvidia.com/gpu.product=NVIDIA-L4 && echo yes)"
check_eq "trainer: 1 ready, on the H100 node" "1 yes" "$(jp deploy/trainer '{.status.readyReplicas}' -n $NS) $(pods_on_nodes_with app=trainer nvidia.com/gpu.product=NVIDIA-H100-80GB-HBM3 && echo yes)"
check_eq "Deployments unchanged (no hand-added GPU tolerations/selectors; trainer still asks for H100 x8)" "|| NVIDIA-H100-80GB-HBM3 dedicated 8" \
  "$(jp deploy/chat '{.spec.template.spec.tolerations}|{.spec.template.spec.nodeSelector}|' -n $NS)$(jp deploy/web '{.spec.template.spec.tolerations}' -n $NS) $(jp deploy/trainer '{.spec.template.spec.nodeSelector.nvidia\.com/gpu\.product} {.spec.template.spec.tolerations[*].key} {.spec.template.spec.containers[0].resources.limits.nvidia\.com/gpu}' -n $NS)"
why "Let the policy do it. kdrill reset restores the Deployments."
check_eq "Still 4 nodes" 4 "$(kubectl get nodes -l "$LESSON_LABEL_KEY" --no-headers 2>/dev/null | wc -l | tr -d ' ')"
