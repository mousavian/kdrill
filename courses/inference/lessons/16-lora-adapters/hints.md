    kubectl exec client -- ask -m sql-lora -n 12 -c 3 http://edge/v1/chat/completions       # who answers, who says 404?
    kubectl get cm epp-config -o jsonpath='{.data.plugins\.yaml}'
    kubectl exec client -- curl -s http://<pod-ip>:8000/metrics | grep lora

Each replica reports which adapters it has loaded in the metric `vllm:lora_requests_info`; the picker's data layer reads it.
The picker has a scorer that prefers replicas where the requested model (adapter) is already active.
---
In `epp-config` add the plugin and use it in the profile:

    plugins:
    - type: lora-affinity-scorer
      name: lora-affinity
    ...
    schedulingProfiles:
    - name: default
      plugins:
      - pluginRef: lora-affinity
        weight: 10
      (the existing queue and kv-cache entries stay)

then `kubectl rollout restart deploy/epp` (the picker reads its file at start).
---
    kubectl apply -f solution/epp-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/epp && kubectl rollout status deploy/epp
