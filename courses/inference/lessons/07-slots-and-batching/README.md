# Server-side concurrency: slots, batching and context

Model server: **real** (llama.cpp, SmolLM2-135M).

## Concept

A model server does not generate one answer after another. It keeps several conversations ("slots", "sequences")
in flight and advances them **together**: at each step it feeds one token per active conversation through the model in
one batch. Reading the weights from memory is the expensive part and the batch shares it, so four
conversations together cost much less than four times one. This **continuous batching** (new requests join the batch
as others finish, with no waiting for the whole batch) is what makes GPU serving economical.

The trade-off is a dial: more concurrent sequences means higher **throughput** (tokens/s for the whole server) but each user's
tokens come a little slower (**latency**), up to the point where the batch is compute-bound; and the KV cache, memory
per token per sequence (lesson 04), bounds how many sequences of what length fit. On a GPU the throughput gain is large (many
times, because decoding is limited by memory bandwidth); on this lab's two CPU threads there is almost none, so here the gain you
can measure is **no waiting**, not more tokens per second (look at the time column of `ask -v`: the last user no longer waits for the others). llama.cpp's dial is `--parallel` (slots) and
`-c` (total context, split between slots); vLLM's is `--max-num-seqs` and `--max-model-len`.

A request that finds every slot busy **waits** (`requests_deferred`, lesson 06). Waiting is not an error but it is latency, and
it is exactly what you watch to decide on more slots or more replicas (lesson 09).

## The situation

Deployment `llm`: `-c 1024 --parallel 1`, memory limit 400Mi. Four users asking together are served one after another:
the last one waits for three full answers.

## Your task

Edit the server arguments (not the memory limit) so that:

- there are at least 4 slots, each with a context of at least 512 tokens (`GET /slots`);
- four users asking at the same time are all answered and `requests_deferred` stays 0 (verify samples it while they run);
- a prompt of about 300 tokens (30 sentences) still fits and is answered;
- the pod's peak memory has 15% headroom under the 400Mi limit.

## Useful commands

    kubectl exec client -- ask -v -n 4 -c 4 -t 48 -p 'Count from one to fifty.' http://llm/v1/chat/completions
    kubectl exec client -- curl -s http://llm/slots | head -c 300
    kubectl exec client -- curl -s http://llm/metrics | grep -E 'deferred|processing'
    kubectl exec deploy/llm -- grep VmHWM /proc/1/status

When you think you're done: `kdrill verify`

## On a real cluster

Tune `--max-num-seqs` and `--max-num-batched-tokens` with a load test at your real prompt and output lengths (vLLM benchmark scripts); look at
the "maximum concurrency" line vLLM prints at start-up; chunked prefill keeps long prompts from stalling the decoding of other
users. Disaggregated prefill/decode (llm-d) splits the two phases onto different replicas.

## Read more

- https://docs.vllm.ai/en/latest/configuration/optimization.html
- https://www.usenix.org/conference/osdi22/presentation/yu (continuous batching: Orca)
- https://github.com/ggml-org/llama.cpp/tree/master/tools/server#server-specific-params
