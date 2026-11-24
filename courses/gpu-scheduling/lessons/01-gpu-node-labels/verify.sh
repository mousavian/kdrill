source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
REQ='{.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[*].matchExpressions'
aff() {  # expr DEPLOY KEY FIELD -> operator / values of the required term on KEY
  jp "deploy/$1" "$REQ[?(@.key==\"$2\")].$3}"
}

# --- llm-serve
check_eq "llm-serve: 2 replicas, both ready" 2 "$(jp deploy/llm-serve '{.status.readyReplicas}')"
why "Pending? kubectl describe pod -l app=llm-serve, then compare its rule with: kubectl get nodes -L nvidia.com/gpu.product,nvidia.com/gpu.memory"
check "llm-serve pods run on the H100 node" pods_on_nodes_with app=llm-serve nvidia.com/gpu.product=NVIDIA-H100-80GB-HBM3
op="$(aff llm-serve nvidia.com/gpu.memory operator)"; val="$(aff llm-serve nvidia.com/gpu.memory 'values[0]')"
check "llm-serve has a required node affinity: nvidia.com/gpu.memory Gt <MiB> that admits 80 GB GPUs and excludes the 48 GB L40S" \
  bash -c '[[ "$1" == Gt && "$2" =~ ^[0-9]+$ ]] && (( $2 >= 46068 && $2 < 81559 ))' _ "$op" "$val"
why "Select by memory, not by name: matchExpressions: [{key: nvidia.com/gpu.memory, operator: Gt, values: [\"70000\"]}] (MiB)."
check "llm-serve no longer selects on nvidia.com/gpu.product" bash -c '[[ " $1 " != *" nvidia.com/gpu.product "* ]]' _ "$(required_affinity_keys deploy/llm-serve)"
why "A product-name rule breaks the day an H200 node joins. Remove the nodeSelector on nvidia.com/gpu.product."
check_eq "llm-serve still asks for 4 GPUs per pod" 4 "$(res_limit nvidia.com/gpu deploy/llm-serve)"

# --- whisper
check_eq "whisper: 2 replicas, both ready" 2 "$(jp deploy/whisper '{.status.readyReplicas}')"
check "whisper pods run only on Turing or Ampere GPUs (T4 / A10G nodes)" pods_on_nodes_with app=whisper 'nvidia.com/gpu.family in (turing,ampere)'
why "kubectl get pods -o wide -l app=whisper. An H100 is far too expensive for speech-to-text."
wop="$(aff whisper nvidia.com/gpu.family operator)"; wval=" $(aff whisper nvidia.com/gpu.family 'values[*]') "
check "whisper has a required node affinity on nvidia.com/gpu.family (In: turing, ampere)" \
  bash -c '[[ "$1" == In && "$2" == *" turing "* && "$2" == *" ampere "* && "$2" != *" hopper "* && "$2" != *" ada-lovelace "* ]]' _ "$wop" "$wval"
why "matchExpressions: [{key: nvidia.com/gpu.family, operator: In, values: [turing, ampere]}]"
check_eq "whisper still asks for 1 GPU per pod" 1 "$(res_limit nvidia.com/gpu deploy/whisper)"

# --- etl
check_eq "etl: 3 replicas, all ready" 3 "$(jp deploy/etl '{.status.readyReplicas}')"
check "etl pods run only on nodes without GPUs" pods_on_nodes_with app=etl '!nvidia.com/gpu.present'
why "CPU jobs on GPU nodes take the CPU and memory the GPU pods need."
eop="$(aff etl nvidia.com/gpu.present operator)$(aff etl feature.node.kubernetes.io/pci-10de.present operator)"
check "etl has a required node affinity: nvidia.com/gpu.present (or the NFD pci-10de label) DoesNotExist" bash -c '[[ "$1" == *DoesNotExist* ]]' _ "$eop"
why "matchExpressions: [{key: nvidia.com/gpu.present, operator: DoesNotExist}]"

# --- guards
check_eq "Replica counts unchanged (llm-serve 2, whisper 2, etl 3)" "2 2 3" \
  "$(jp deploy/llm-serve '{.spec.replicas}') $(jp deploy/whisper '{.spec.replicas}') $(jp deploy/etl '{.spec.replicas}')"
check_eq "Still 6 nodes in the fleet" 6 "$(fake_node_count)"
check_fleet_unchanged
