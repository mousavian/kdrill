    kubectl logs job/train | tail -n 3          # tok/s
    kubectl get job train -o jsonpath='{.spec.template.spec.containers[0].resources}'
    kubectl exec job/train -- cat /sys/fs/cgroup/cpu.stat   # nr_throttled (cgroup v2)
    kubectl run help --rm -it --restart=Never --image=kdrill.local/ml-tiny:0.1.0 -- train --help | grep -i metrics

What does a CPU limit of 250m do to a process that wants a whole core?
---
- Metrics: `METRICS_PORT=9090` in the container, a `containerPort` 9090 named
  `metrics`, and a Service `train-metrics` (port 9090) that selects
  `batch.kubernetes.io/job-name: train`.
- Speed: CPU limit (and request) of 1 or 2, `OMP_NUM_THREADS` equal to the
  limit. Keep `STEPS=3000`.
---
    kubectl delete job train
    kubectl apply -f solution/train.yaml -f solution/service.yaml
    kdrill verify     # while it runs
