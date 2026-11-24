source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
gpu_node h100-1 h100 8 --cpu 192 --mem 2048Gi
wait_nodes_ready
kubectl apply -f - >/dev/null <<YAML
apiVersion: kueue.x-k8s.io/v1beta2
kind: ResourceFlavor
metadata:
  name: h100
  labels: {$LESSON_LABEL_KEY: "$KDRILL_LESSON"}
spec:
  nodeLabels: {nvidia.com/gpu.product: NVIDIA-H100-80GB-HBM3}
YAML
for t in team-a team-b; do
  kubectl apply -f - >/dev/null <<YAML
apiVersion: kueue.x-k8s.io/v1beta2
kind: ClusterQueue
metadata:
  name: $t-cq
  labels: {$LESSON_LABEL_KEY: "$KDRILL_LESSON"}
spec:
  namespaceSelector:
    matchLabels: {kubernetes.io/metadata.name: $t}
  resourceGroups:
  - coveredResources: [cpu, memory, nvidia.com/gpu]
    flavors:
    - name: h100
      resources:
      - {name: cpu, nominalQuota: 96}
      - {name: memory, nominalQuota: 1024Gi}
      - {name: nvidia.com/gpu, nominalQuota: 4}
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: LocalQueue
metadata:
  name: $t
  namespace: $t
spec:
  clusterQueue: $t-cq
YAML
done
baseline_save quotas
apply_lesson manifests/team-a-jobs.yaml
wait_running 30 1 batch.kubernetes.io/job-name team-a || true
