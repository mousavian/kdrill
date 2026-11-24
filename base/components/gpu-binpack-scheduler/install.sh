# A second kube-scheduler with one profile, "gpu-binpack", that packs pods onto
# the nodes whose GPUs are already most allocated. Pods opt in with
#   spec.schedulerName: gpu-binpack
# Everything else keeps using the cluster's default scheduler.
SCHED_VERSION="${SCHED_VERSION:-v1.35.5}"
kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gpu-binpack-scheduler
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gpu-binpack-scheduler:kube-scheduler
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: system:kube-scheduler}
subjects: [{kind: ServiceAccount, name: gpu-binpack-scheduler, namespace: kube-system}]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gpu-binpack-scheduler:volume-scheduler
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: system:volume-scheduler}
subjects: [{kind: ServiceAccount, name: gpu-binpack-scheduler, namespace: kube-system}]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gpu-binpack-scheduler:auth-reader
  namespace: kube-system
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: extension-apiserver-authentication-reader}
subjects: [{kind: ServiceAccount, name: gpu-binpack-scheduler, namespace: kube-system}]
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: gpu-binpack-scheduler
  namespace: kube-system
data:
  config.yaml: |
    apiVersion: kubescheduler.config.k8s.io/v1
    kind: KubeSchedulerConfiguration
    leaderElection:
      leaderElect: false
    profiles:
    - schedulerName: gpu-binpack
      plugins:
        score:
          disabled:
          # Both of these favour spreading; a bin-packing profile drops them.
          - name: NodeResourcesBalancedAllocation
          - name: PodTopologySpread
      pluginConfig:
      - name: NodeResourcesFit
        args:
          scoringStrategy:
            type: MostAllocated        # prefer the fullest node that still fits
            resources:
            - {name: nvidia.com/gpu, weight: 10}
            - {name: cpu, weight: 1}
            - {name: memory, weight: 1}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-binpack-scheduler
  namespace: kube-system
  labels: {app: gpu-binpack-scheduler}
spec:
  replicas: 1
  selector:
    matchLabels: {app: gpu-binpack-scheduler}
  template:
    metadata:
      labels: {app: gpu-binpack-scheduler}
    spec:
      serviceAccountName: gpu-binpack-scheduler
      priorityClassName: system-cluster-critical
      tolerations: [{operator: Exists}]
      containers:
      - name: kube-scheduler
        image: registry.k8s.io/kube-scheduler:${SCHED_VERSION}
        command: [kube-scheduler, --config=/etc/gpu-binpack/config.yaml, --v=2]
        resources:
          requests: {cpu: 20m, memory: 48Mi}
          limits: {memory: 192Mi}
        livenessProbe:
          httpGet: {path: /livez, port: 10259, scheme: HTTPS}
          initialDelaySeconds: 15
        readinessProbe:
          httpGet: {path: /readyz, port: 10259, scheme: HTTPS}
        volumeMounts:
        - {name: config, mountPath: /etc/gpu-binpack}
      volumes:
      - name: config
        configMap: {name: gpu-binpack-scheduler}
YAML
kubectl -n kube-system rollout status deploy/gpu-binpack-scheduler --timeout=180s >/dev/null
info "gpu-binpack scheduler ${SCHED_VERSION} ready (schedulerName: gpu-binpack)"
