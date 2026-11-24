source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
# 8 H100s partitioned with the "all-balanced" MIG profile set:
# per GPU 2 x 1g.10gb + 1 x 2g.20gb + 1 x 3g.40gb  (mixed strategy)
gpu_node h100-mig-1 h100 8 --cpu 192 --mem 2048Gi --mig-config all-balanced \
  --mig 1g.10gb=16 --mig 2g.20gb=8 --mig 3g.40gb=8
# 8 H100s with MIG disabled: whole GPUs
gpu_node h100-1 h100 8 --cpu 192 --mem 2048Gi --label nvidia.com/mig.config=all-disabled
wait_nodes_ready
baseline_save
apply_lesson manifests/embed.yaml manifests/rerank.yaml
wait_running 40 8 'app in (embed,rerank)' || true
apply_lesson manifests/pretrain.yaml
sleep 2
