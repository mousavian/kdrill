source "$KDRILL_HOME/courses/kyverno/lib.sh"
kyv_wait_ready
lesson_nodes
fake_node gpu-1 --cpu 48 --mem 192Gi --gpu 4 --taint nvidia.com/gpu=present:NoSchedule \
  --label nvidia.com/gpu.present=true --label nvidia.com/gpu.product=NVIDIA-L4
wait_nodes_ready
kubectl label ns payments env=prod --overwrite >/dev/null
kubectl label ns analytics env=prod --overwrite >/dev/null
kubectl label ns playground env=dev --overwrite >/dev/null
kyv_apply manifests/policies.yaml
wait_until 30 _all_policies_ready || true
sleep 3
apply_lesson manifests/workloads.yaml
sleep 3
