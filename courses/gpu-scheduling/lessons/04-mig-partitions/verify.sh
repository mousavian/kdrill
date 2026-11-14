source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"

check_eq "pretrain: its 8-GPU pod is Running" 1 "$(jp deploy/pretrain '{.status.readyReplicas}')"
why "Whole H100s are taken by small inference pods. kubectl describe node h100-1 | grep -A10 'Allocated resources'"
check_eq "pretrain still asks for 8 whole GPUs (nvidia.com/gpu: 8)" 8 "$(res_limit nvidia.com/gpu deploy/pretrain)"

check_eq "embed: 8 replicas, all ready" 8 "$(jp deploy/embed '{.status.readyReplicas}')"
check_eq "embed asks for one 1g.10gb slice (limits nvidia.com/mig-1g.10gb: 1)" 1 "$(res_limit nvidia.com/mig-1g.10gb deploy/embed)"
why "A 3 GB embedding model fits in the smallest slice: limits: {nvidia.com/mig-1g.10gb: 1}"
check "embed no longer asks for nvidia.com/gpu" bash -c '[[ "$1" != *nvidia.com/gpu* ]]' _ "$(res_keys deploy/embed)"
why "Remove nvidia.com/gpu from both limits and requests; a pod asking for both needs a whole GPU AND a slice."

check_eq "rerank: 4 replicas, all ready" 4 "$(jp deploy/rerank '{.status.readyReplicas}')"
check_eq "rerank asks for one 2g.20gb slice (limits nvidia.com/mig-2g.20gb: 1)" 1 "$(res_limit nvidia.com/mig-2g.20gb deploy/rerank)"
why "~15 GB does not fit 1g.10gb; 2g.20gb is the smallest slice that does. 3g.40gb would waste half of it."
check "rerank asks for no other GPU resource (no nvidia.com/gpu, no other MIG profile)" \
  bash -c '[[ "$1" != *nvidia.com/gpu* && "$1" != *mig-1g* && "$1" != *mig-3g* ]]' _ "$(res_keys deploy/rerank)"

check_eq "Replica counts unchanged (embed 8, rerank 4, pretrain 1)" "8 4 1" \
  "$(jp deploy/embed '{.spec.replicas}') $(jp deploy/rerank '{.spec.replicas}') $(jp deploy/pretrain '{.spec.replicas}')"
check_eq "Still 2 nodes" 2 "$(fake_node_count)"
check_fleet_unchanged
