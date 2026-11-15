# Solution

From the lesson directory:

    kubectl delete job train
    kubectl apply -f solution/train.yaml -f solution/service.yaml
    kubectl run scrape --rm -it --restart=Never --image=kdrill.local/ml-tiny:0.1.0 -- \
      python3 -c "import urllib.request; print(urllib.request.urlopen('http://train-metrics:9090/metrics').read().decode())"

- `METRICS_PORT=9090` makes `train` serve Prometheus text on `/metrics`
  (`kdrill_train_step`, `kdrill_train_loss`, `kdrill_train_tokens_per_second`,
  `kdrill_train_step_seconds`, the container's CFS throttling counters, ...).
  A Service selecting the Job's pod (label `batch.kubernetes.io/job-name`)
  gives it a stable address for Prometheus or for you; a Prometheus Operator
  setup would add a PodMonitor or ServiceMonitor.
- Why it was slow: a CPU **limit** of 250m means the container may use 25 ms
  of CPU every 100 ms period. A training step needs a whole core for much
  longer, so the process ran a quarter of each period and was **throttled**
  for the rest (`nr_throttled` grows almost every period in `cpu.stat`;
  `kdrill_train_cpu_throttled_periods_total` on a cgroup v2 host). One thread
  needs a limit of at least 1 CPU; more threads need more.
- The request is what the scheduler reserves; raising it with the limit keeps
  the node from being overcommitted.
