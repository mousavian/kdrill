# Why a CPU-based HPA is blind to a model server

Model server: **simulator** (2 concurrent requests per replica, about 2.3 s per answer).

## Concept

The HorizontalPodAutoscaler is Kubernetes' built-in autoscaler. Out of the box it
scales on **resource metrics** (CPU and memory, from metrics-server): it
compares average utilisation, usage divided by the pod's *request*, with a
target, and sets `replicas = ceil(current x utilisation / target)`.

That works for stateless web servers because CPU rises with load. A model server
breaks the assumption in both directions:

- on a **GPU server** the CPU only prepares batches and moves data; the GPU is the
  bottleneck. The server can be saturated (requests queueing, latency up) while
  its CPU sits at 5%;
- on a **CPU server** (like llama.cpp here) the threads spin at 100% from the
  first request whether one request or fifty are waiting, so utilisation says
  "busy", not "overloaded".

Memory is no better: it is allocated up front (lesson 04) and does not move
with load. What does move are the server's own metrics: requests running and
waiting, KV-cache usage, time to first token (lesson 06). To autoscale on them
the HPA needs *custom* or *external* metrics, which means a metrics adapter
(Prometheus Adapter, or KEDA, next lesson).

Two rules to remember: an HPA owns `spec.replicas` (manual scaling is reverted),
and there must be only one autoscaler per Deployment.

## The situation

Deployment `llm` (simulator, `max-num-seqs 2`, CPU request 500m), an HPA on 50% CPU
(min 1, max 5), eight users sending requests all the time (`users`), and an
`aggregator` that sums the replicas' metrics into one JSON document
(`curl http://aggregator/`: `running`, `waiting`, `inflight`, `replicas`...). metrics-server is
installed, so `kubectl top` and the HPA's CPU column work.

## Your task

- see for yourself what the HPA reads and what the queue looks like;
- remove the HPA, and scale `llm` so that 8 users fit: at least 4 ready replicas;
- the queue has shrunk (at most 3 requests waiting across all replicas, down from 6; the Service balances randomly, so one or two may still wait);
- leave the users and the per-replica concurrency alone.

## Useful commands

    kubectl get hpa llm
    kubectl describe hpa llm | tail -15
    kubectl top pods
    kubectl exec client -- curl -s http://aggregator/

When you think you're done: `kdrill verify` (it waits up to a minute for pods and queue).

## On a real cluster

The same: CPU-based autoscaling of GPU model servers is a well-known mistake.
Production setups scale on queue/concurrency (KEDA or Prometheus Adapter with
vLLM metrics), or on a platform that does it for you (KServe, llm-d's
workload-variant autoscaler, cloud inference endpoints).

## Read more

- https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#algorithm-details
- https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/
- https://github.com/kubernetes-sigs/metrics-server
