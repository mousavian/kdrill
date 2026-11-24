source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
T=nvidia.com/gpu=present:NoSchedule      # every GPU node carries this taint
gpu_node h100-1 h100 8 --cpu 192 --mem 2048Gi --taint "$T"
gpu_node l4-1   l4   8 --taint "$T"
gpu_node mig-1  a100 2 --mig-config all-1g.10gb --mig 1g.10gb=14 --taint "$T"
gpu_node dra-1  l40s 2 --dra --taint "$T"
wait_nodes_ready
dra_slice dra-1 l40s 2
gpu_device_class
kubectl apply -f - >/dev/null <<YAML
apiVersion: kueue.x-k8s.io/v1beta2
kind: ResourceFlavor
metadata:
  name: l4
  labels: {$LESSON_LABEL_KEY: "$KDRILL_LESSON"}
spec:
  nodeLabels: {nvidia.com/gpu.product: NVIDIA-L4}
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: ClusterQueue
metadata:
  name: research-cq
  labels: {$LESSON_LABEL_KEY: "$KDRILL_LESSON"}
spec:
  namespaceSelector:
    matchLabels: {kubernetes.io/metadata.name: research}
  resourceGroups:
  - coveredResources: [cpu, memory, nvidia.com/gpu]
    flavors:
    - name: l4
      resources:
      - {name: cpu, nominalQuota: 32}
      - {name: memory, nominalQuota: 128Gi}
      - {name: nvidia.com/gpu, nominalQuota: 4}
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: LocalQueue
metadata:
  name: research-queue
  namespace: research
spec:
  clusterQueue: research-cq
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute
  namespace: research
spec:
  hard:
    requests.cpu: "64"
    requests.memory: 256Gi
    requests.nvidia.com/gpu: "4"
YAML
baseline_save capstone_config
kubectl apply -f "$KDRILL_LESSON_DIR/manifests/prod.yaml" >/dev/null
kubectl apply -f "$KDRILL_LESSON_DIR/manifests/research.yaml" >/dev/null
sleep 3
