source "$KDRILL_HOME/courses/kyverno/lib.sh"
kyv_wait_ready
lesson_nodes
G=nvidia.com/gpu=present:NoSchedule
fake_node l4-1 --cpu 48 --mem 192Gi --gpu 4 --taint "$G" \
  --label nvidia.com/gpu.present=true --label nvidia.com/gpu.product=NVIDIA-L4 --label node.kubernetes.io/instance-type=g6.12xlarge
fake_node h100-1 --cpu 192 --mem 2048Gi --gpu 8 --taint "$G" --taint dedicated=training:NoSchedule \
  --label nvidia.com/gpu.present=true --label nvidia.com/gpu.product=NVIDIA-H100-80GB-HBM3 --label node.kubernetes.io/instance-type=p5.48xlarge
wait_nodes_ready
kyv_apply manifests/policy.yaml
wait_until 30 policy_ready gpu-defaults || true
sleep 3
apply_lesson manifests/workloads.yaml
sleep 3
