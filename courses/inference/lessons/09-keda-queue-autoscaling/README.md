# Autoscaling on in-flight requests with KEDA

Model server: **simulator** (2 concurrent requests per replica, about 2.3 s per answer).

## Concept

To autoscale a model server you need a signal that reflects *demand* and a
controller that can read it. **KEDA** is an autoscaler add-on: a `ScaledObject`
points at a Deployment and lists *triggers*; KEDA reads them and manages an
ordinary HPA for you (`keda-hpa-<name>`), feeding it the numbers through the
external-metrics API. There are scalers for Prometheus, queues, cron, and a
generic **metrics-api** scaler that fetches a URL and reads one value from a
JSON document, which is what this lab uses because it has no Prometheus. (With
Prometheus you would write the same idea as a `prometheus` trigger with
`sum(vllm:num_requests_running + vllm:num_requests_waiting)`.)

What to measure is the hard part:

- **running** saturates at the number of slots, so it cannot ask for more capacity;
- **waiting** (queue length) is zero until you are overloaded and drops when you
  scale out: the autoscaler chases its own tail;
- **in-flight = running + waiting** is the demand. With a target equal to the
  slots per replica, `ceil(in-flight / target)` is the replica count that serves
  everyone without queueing. Many teams use the queue plus a utilisation
  target such as KV-cache usage; start with in-flight and measure.

Behaviour matters as much as the signal: `pollingInterval` (how often KEDA
looks), the HPA's *stabilisation windows* (how long it waits before acting on a
fall in load), and the min/max bounds. Scaling up fast and down slowly protects
latency and avoids re-loading models. A ScaledObject and a hand-made HPA on the
same Deployment fight (KEDA makes its own HPA), so there must be exactly one.

## The situation

The Deployment `llm` (simulator, `max-num-seqs 2`), eight users (`users`), the
`aggregator` (`kubectl exec client -- curl -s http://aggregator/` gives
`running`, `waiting`, `inflight`, `replicas`...) and a ScaledObject `llm` that never scales.

## Your task

Edit the ScaledObject so that it:

- uses the `metrics-api` trigger on the aggregator's field `inflight` with `targetValue: "2"`;
- may scale to at least 4 replicas, has a minimum of 1 or 2, polls every 10 s or less, and
  scales down after a stabilisation window of 30 s or less;
- (there must be no other HPA on `llm`).

verify then checks behaviour: with eight users the Deployment reaches at least 4
ready replicas and the queue drains; verify then stops the users and waits for
the replica count to fall back to 2 or fewer; finally it restarts the users.
**It takes up to two minutes.**

## Useful commands

    kubectl get scaledobject,hpa
    kubectl describe scaledobject llm
    kubectl explain scaledobject.spec.advanced.horizontalPodAutoscalerConfig.behavior
    kubectl exec client -- curl -s http://aggregator/
    kubectl -n keda logs deploy/keda-operator --tail=20

When you think you're done: `kdrill verify`

## On a real cluster

Use the Prometheus scaler (or Prometheus Adapter) with vLLM's own metrics; scale on
`num_requests_waiting`/`running` and KV-cache usage together; keep the minimum at
the number of replicas you need warm (lesson 10), set `scaleDown`
`stabilizationWindowSeconds` of minutes, not seconds; and make sure new GPU pods
can actually be scheduled (Karpenter or cluster-autoscaler: see the karpenter course). Llm-d's
workload-variant autoscaler and KServe's autoscaling do this natively.

## Read more

- https://keda.sh/docs/2.21/scalers/metrics-api/
- https://keda.sh/docs/2.21/reference/scaledobject-spec/
- https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#configurable-scaling-behavior
