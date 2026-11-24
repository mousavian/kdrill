# Solution

From the lesson directory:

    kubectl apply -f solution/llm.yaml

    -c 4096 --parallel 4 -t 2          # 4 slots x 1024 tokens, 2 threads
    resources: requests.memory = limits.memory = 400Mi, limits.cpu = 2

Why these numbers (measured on this image, SmolLM2-135M Q4_K_M):

| -c | peak RSS |
|---|---|
| 512 | 216 MB |
| 2048 | 244 MB |
| 4096 | ~300 MB |
| 8192 | 381 MB |
| 32768 | 890 MB |

About 200 MB is the weights plus the runtime; every token of context adds about
23 KB (30 layers x 2 (K and V) x 192 values x 2 bytes). `-c 32768` therefore needed
about 890 MB and was killed in a 300 Mi box; shrinking the context to what the
workload needs (4 conversations x 1024 tokens) brings it to ~300 MB, and a 400Mi
limit leaves more than 15% headroom. Requests equal to limits means the memory is
reserved up front.

`-t 2` matches the CPU limit of 2 cores: threads beyond the quota just get
throttled.

The same arithmetic on a GPU: memory = weights (parameters x bytes per parameter:
70B x 2 B = 140 GB in 16-bit, 35 GB at 4-bit) + KV cache (tokens x 2 x layers x
kv_heads x head_dim x bytes) + activations and runtime (a few GB). vLLM's
`--max-model-len`, `--max-num-seqs` and `--gpu-memory-utilization` are the knobs
that correspond to `-c`, `--parallel` and the memory limit here.
