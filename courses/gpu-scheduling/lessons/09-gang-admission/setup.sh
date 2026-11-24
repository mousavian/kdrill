source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
gpu_node gpu-1 l40s 2
gpu_node gpu-2 l40s 2
wait_nodes_ready
kubectl apply -f - >/dev/null <<YAML
apiVersion: kueue.x-k8s.io/v1beta2
kind: ResourceFlavor
metadata:
  name: l40s
  labels: {$LESSON_LABEL_KEY: "$KDRILL_LESSON"}
spec:
  nodeLabels: {nvidia.com/gpu.product: NVIDIA-L40S}
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: ClusterQueue
metadata:
  name: training-cq
  labels: {$LESSON_LABEL_KEY: "$KDRILL_LESSON"}
spec:
  namespaceSelector: {}
  resourceGroups:
  - coveredResources: [cpu, memory, nvidia.com/gpu]
    flavors:
    - name: l40s
      resources:
      - {name: cpu, nominalQuota: 48}
      - {name: memory, nominalQuota: 512Gi}
      - {name: nvidia.com/gpu, nominalQuota: 4}   # = the GPUs the nodes really have
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: LocalQueue
metadata:
  name: training
  namespace: training
spec:
  clusterQueue: training-cq
YAML
baseline_save quotas
# Simulate two jobs submitted at the same moment: the scheduler interleaves
# their pods, each job gets half its workers and both wait for the rest.
apply_lesson manifests/jobs.yaml
kubectl -n training patch job llama-ft   --type merge -p '{"spec":{"parallelism":2}}' >/dev/null
kubectl -n training patch job mistral-ft --type merge -p '{"spec":{"parallelism":2}}' >/dev/null
both_half() { [[ "$(job_running llama-ft training)$(job_running mistral-ft training)" == 22 ]]; }
wait_until 30 both_half || true
kubectl -n training patch job llama-ft   --type merge -p '{"spec":{"parallelism":4}}' >/dev/null
kubectl -n training patch job mistral-ft --type merge -p '{"spec":{"parallelism":4}}' >/dev/null
sleep 3
