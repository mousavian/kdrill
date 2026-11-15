# The metrics that matter: queue, throughput, cache

Model server: **real** (llama.cpp, SmolLM2-135M, one slot).

## Concept

CPU and memory tell you almost nothing about a model server: a GPU-bound server
shows idle CPUs while it is saturated, and its memory is allocated at start
and never moves. What matters is what the engine itself reports, usually as
Prometheus metrics on `/metrics`. The set is small:

- **requests running / waiting** (`vllm:num_requests_running`,
  `vllm:num_requests_waiting`): how many requests are being generated and how
  many are queued for a slot. *Waiting* is the most useful single number for
  autoscaling and routing (lessons 09 and 15).
- **KV-cache usage** (`vllm:kv_cache_usage_perc`): how full the GPU memory
  reserved for attention state is. Near 100% new requests are queued or evict
  others, however few are running.
- **latency**: *time to first token* (TTFT, queueing + prefill) and *time per
  output token* (decode speed), as histograms (`vllm:time_to_first_token_seconds`,
  `vllm:time_per_output_token_seconds`), so you read percentiles, not averages.
- **throughput**: generated and prompt tokens as counters
  (`vllm:generation_tokens_total`); tokens per second is their *rate*.

A **counter** only goes up: look at its change over time (PromQL `rate()`). A
**gauge** is a value now. A **histogram** is a set of counters per latency bucket.
Different engines use different names for the same things (vLLM, SGLang, TGI,
Triton, llama.cpp), which is why routers and autoscalers map them (the llm-d
endpoint picker in lesson 15 understands several).

llama.cpp's server exposes a smaller set and only when started with `--metrics`.

## The situation

`llm` is the real server with **one** slot (`--parallel 1`) and no metrics. A
Deployment `users` keeps three requests in flight at all times (24 tokens each).
At any moment one is being generated and the others wait. There is no Prometheus
in this lab: read the endpoint with curl from the client pod.

## Your task

1. Turn on the server's metrics endpoint.
2. Create the ConfigMap `findings` with keys:
   - `waiting-metric`: the gauge counting requests waiting for a slot;
   - `running-metric`: the gauge counting requests being generated;
   - `tokens-metric`: the counter of generated tokens;
   - `queue-depth`: how many requests are waiting right now (an integer);
   - `tokens-per-second`: the generation rate, from two reads of the counter
     (verify accepts a value within a factor of two of what it measures: the rate varies with the load).

Leave the server's slot count and the users alone: verify checks your numbers
against the live server.

## Useful commands

    kubectl exec client -- curl -s http://llm/metrics | grep -E '^(# HELP|llamacpp)'
    kubectl exec client -- curl -s http://llm/slots | head -c 300
    kubectl logs deploy/llm | tail

When you think you're done: `kdrill verify` (it samples the server for about 12 s).

## On a real cluster

Prometheus (or a compatible agent) scrapes every pod's `/metrics` and an
autoscaler or dashboard queries it with PromQL, for example
`sum(vllm:num_requests_waiting)` or
`histogram_quantile(0.95, rate(vllm:time_to_first_token_seconds_bucket[5m]))`. On
NVIDIA GPUs the DCGM exporter adds GPU utilisation, memory and power. This lab
has no Prometheus: lessons 09 onwards read the same metrics through a tiny
aggregator.

## Read more

- https://github.com/ggml-org/llama.cpp/tree/master/tools/server#get-metrics-prometheus-compatible-metrics-exporter
- https://docs.vllm.ai/en/latest/design/metrics.html
- https://prometheus.io/docs/practices/instrumentation/#counter-vs-gauge-summary-vs-histogram
