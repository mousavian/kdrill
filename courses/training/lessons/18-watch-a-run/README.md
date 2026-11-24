# Watching a run: metrics, and why it is slow

## Concept

A run that takes days is watched, not read: you want its step, loss and
throughput on a dashboard and an alert when it stalls. The usual route on
Kubernetes is a **Prometheus endpoint**: the training process serves its
numbers as plain text on `/metrics`, a Service (or a PodMonitor) makes the pod
reachable, and Prometheus scrapes it every few seconds. Throughput
(tokens or samples per second, seconds per step) is the number that tells you
something is wrong long before the loss does.

The most common reason for a slow run that is not the code is the **CPU
limit**. Limits are enforced by the CFS bandwidth controller: a limit of 250m
gives the container 25 ms of CPU time in every 100 ms period. A training loop
that needs a full core runs for 25 ms, is **throttled** (stopped) for 75 ms,
and so on: it runs at a quarter of its speed, with the node mostly idle. The
kernel counts it in the container's `cpu.stat` (`nr_periods`,
`nr_throttled`, `throttled_usec`), and cAdvisor exposes it as
`container_cpu_cfs_throttled_periods_total`. Several threads under a small
limit make it worse: they burn the period's quota in parallel and then all
wait.

The course's `train` serves `/metrics` when `METRICS_PORT` is set:
`kdrill_train_step`, `kdrill_train_loss`, `kdrill_train_tokens_per_second`,
`kdrill_train_step_seconds`, `kdrill_train_threads` and the container's
throttling counters (read from cgroup v2; on cgroup v1 nodes they may stay 0).

## The situation

Job `train` (3000 steps) runs with a CPU limit of 250m. Setup measured its
throughput after 50 steps. There is no way to see its progress except logs.

## Your task

- Job `train` serves its metrics on port 9090 (`METRICS_PORT`), and a Service
  `train-metrics` (port 9090) has the training pod behind it.
- It keeps `STEPS=3000`, has a CPU limit of 1-2 cores and a CPU request no
  higher than the limit, and as many PyTorch threads as the limit.
- **While it runs**, `kdrill verify` scrapes `http://train-metrics:9090/metrics`
  twice: the step must go up, and `kdrill_train_tokens_per_second` must be at
  least 2.5 times the original run's. (On a node that does not enforce CPU
  limits, such as some nested cgroup v1 hosts, setup notices that the
  original run was not slowed down and verify skips this speed check.)

## Useful commands

    kubectl logs job/train | tail -n 3
    kubectl exec job/train -- cat /sys/fs/cgroup/cpu.stat
    kubectl get events --field-selector involvedObject.kind=Pod
    kubectl run scrape --rm -it --restart=Never --image=kdrill.local/ml-tiny:0.1.0 -- \
      python3 -c "import urllib.request; print(urllib.request.urlopen('http://train-metrics:9090/metrics').read().decode())"

The fixed run takes about 4 minutes; verify while it runs (a verify takes
about 10 s).

## On a real cluster

GPU jobs export the same kind of metrics plus GPU ones from the NVIDIA DCGM
exporter (utilisation, memory, NVLink and PCIe traffic); a GPU sitting at 30%
usually means the input pipeline or the CPU limit of the data loader is the
bottleneck. Many teams set CPU requests but no CPU limits on training pods to
avoid throttling altogether, and use Guaranteed QoS with whole cores
(static CPU manager policy) for latency-sensitive data loading.

## Read more

- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#how-pods-with-resource-limits-are-run
- https://docs.kernel.org/scheduler/sched-bwc.html
- https://prometheus.io/docs/instrumenting/exposition_formats/
- https://kubernetes.io/docs/concepts/services-networking/service/
