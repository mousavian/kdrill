# Solution

From the lesson directory:

    kubectl apply -f solution/llm.yaml
    kubectl rollout status deploy/llm --timeout=90s

    -c 2048 --parallel 4        # was -c 1024 --parallel 1

With four slots the server decodes the four conversations **in one batch**: each step reads the weights once and produces a
token for every active conversation. That is **continuous batching**, and it is why a GPU serves many users with little more
work than one. For the users it means: nobody waits for a slot and each conversation advances a little slower than it
would alone (the batch is bigger). On a GPU the *total* throughput is then several times higher than serving them one after another; on
this lab's two CPU threads the compute is the limit, so the gain you see is the absence of queueing, not more tokens per second.

The cost is memory and context. `-c` is shared: `-c 1024 --parallel 4` would give each slot 256 tokens, too few for a long prompt,
so `-c` had to grow with the slot count (4 x 512 = 2048). The KV cache for 2048 tokens is only about 50 MB for this model; for a 70B model
it is several GB, which is exactly what limits `--max-num-seqs` in vLLM: more concurrent sequences or longer
contexts, not both, for a fixed amount of GPU memory (lesson 04).

How to pick the number: raise it until latency per token starts to hurt (the batch becomes compute-bound) or the KV cache is full;
vLLM prints the maximum concurrency its cache supports at start. Serving more concurrent users than slots always queues:
that is what replicas and autoscaling (Part B) are for.
