fake_node cpu-1 --cpu 8 --mem 32Gi
fake_node cpu-2 --cpu 8 --mem 32Gi
for i in 1 2; do
  fake_node "gpu-$i" --cpu 32 --mem 256Gi --gpu 4 \
    --label nvidia.com/gpu.product=NVIDIA-H100-80GB \
    --label nvidia.com/gpu.present=true \
    --taint nvidia.com/gpu=present:NoSchedule
done
wait_nodes_ready
apply_lesson manifests/llm.yaml
wait_until 30 test "$(running_count app=llm)" = 3 || true
