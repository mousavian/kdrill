# Solution

From the lesson directory:

    kubectl apply -f solution/llm.yaml
    kubectl rollout status deploy/llm --timeout=120s
    bash solution/findings.sh

`solution/llm.yaml` adds `--metrics` to the server. `findings.sh` reads the live
numbers and creates the ConfigMap, equivalent to:

    kubectl exec client -- curl -s http://llm/metrics | grep -E '^llamacpp'
    kubectl create configmap findings \
      --from-literal=waiting-metric=llamacpp:requests_deferred \
      --from-literal=running-metric=llamacpp:requests_processing \
      --from-literal=tokens-metric=llamacpp:tokens_predicted_total \
      --from-literal=queue-depth=2 --from-literal=tokens-per-second=55

How to read them (llama.cpp name -> vLLM name):

| meaning | llama.cpp | vLLM | type |
|---|---|---|---|
| requests being generated | `llamacpp:requests_processing` | `vllm:num_requests_running` | gauge |
| requests waiting for a slot | `llamacpp:requests_deferred` | `vllm:num_requests_waiting` | gauge |
| generated tokens | `llamacpp:tokens_predicted_total` | `vllm:generation_tokens_total` | counter |
| prompt tokens | `llamacpp:prompt_tokens_total` | `vllm:prompt_tokens_total` | counter |
| KV cache in use | (not exported) | `vllm:kv_cache_usage_perc` | gauge |
| time to first token | (not exported; use prompt_seconds_total) | `vllm:time_to_first_token_seconds` | histogram |

Three users on one slot is a steady state of 1 running + 2 waiting. Tokens per
second is `rate(generation_tokens_total[1m])` in PromQL; here it is the difference of
two reads of the counter divided by the interval.
