# Sizing: weights plus KV cache, and threads vs CPU

Model server: **real** (llama.cpp, SmolLM2-135M).

## Concept

A model server's memory has three parts:

1. **Weights**: parameters x bytes per parameter. 135M parameters at 4 bits is
   about 100 MB; a 70B model is 140 GB in 16-bit, 35 GB at 4-bit.
2. **KV cache**: for every token of every active conversation the server keeps
   the attention keys and values of every layer, so it does not recompute them
   for each new token. It costs `2 x layers x kv_heads x head_dim x bytes`
   per token (about 23 KB for this tiny model, around 0.3-1 MB per token for a
   7B-70B model) and is allocated up front for the **context size x number of
   slots** you configure, whether or not requests use it.
3. **Runtime**: buffers and the framework itself.

That is why one setting, the context length, can make the same model fit or be
OOMKilled. `-c` in llama.cpp is the total context across `--parallel` slots;
vLLM's equivalents are `--max-model-len`, `--max-num-seqs` and
`--gpu-memory-utilization`. Size the context to the workload, not to the
model's maximum.

CPU has a different trap. Inference threads spin on cores; a container with a CPU
*limit* of 2 is throttled by the kernel's CFS quota whatever its thread count, so
`-t 8` on a 2-core limit makes the extra threads fight for the same quota (more
waiting, no more speed). Set threads to the limit. (Requests only affect
scheduling; limits are what throttle.) For memory the limit is hard: exceed it
and the kernel kills the container (`OOMKilled`, exit 137). Make requests equal
to limits so the memory you rely on is reserved.

## The situation

Deployment `llm`: `-c 32768 --parallel 4 -t 8`, memory limit 300Mi, CPU limit 2.
The server dies during start-up with `OOMKilled`.

## Your task

Edit the Deployment (and only what is needed) so that:

- the pod is ready with no restarts and no OOM;
- the memory limit is at most 450Mi, `requests.memory` equals it, and it is at
  least 15% above the server's measured peak (`VmHWM`);
- the server still has 4 parallel slots with a context of at least 1024 tokens each
  (`GET /slots`);
- `-t` is between 1 and the number of CPU limit cores;
- 4 concurrent completions succeed.

## Useful commands

    kubectl describe pod -l app=llm | grep -B2 -A8 'Last State'
    kubectl logs deploy/llm --previous | grep -E 'n_ctx|KV|slots'
    kubectl exec deploy/llm -- grep -E 'VmHWM|VmRSS' /proc/1/status
    kubectl exec client -- curl -s http://llm/slots | head -c 400

When you think you're done: `kdrill verify`

## On a real cluster

Use `nvidia-smi` / the DCGM exporter for GPU memory; vLLM pre-allocates
`gpu-memory-utilization` (default 0.9) of the GPU for weights plus KV cache and
reports how many tokens of KV cache fit at start ("GPU KV cache size"). Running
out of GPU memory is a CUDA OOM inside the process, not a kubelet kill, so the
pod's memory limit is only for host memory. Quantised weights (AWQ, GPTQ, FP8,
GGUF Q4) trade a little quality for a much smaller footprint.

## Read more

- https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/
- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#how-pods-with-resource-limits-are-run
- https://docs.vllm.ai/en/latest/configuration/optimization.html
- https://github.com/ggml-org/llama.cpp/tree/master/tools/server#usage
