    kubectl exec client -- ask -v -n 4 -c 4 -t 48 http://llm/v1/chat/completions      # four users together; compare the TOTAL column
    kubectl exec client -- curl -s http://llm/slots | head -c 300
    kubectl exec client -- curl -s http://llm/metrics | grep -E 'deferred|processing'

One slot = one conversation generated at a time. Everyone else waits (deferred). Slots are not free: `-c` is the TOTAL context
split between them (23 KB of KV cache per token here), and every slot's context must hold the prompt plus the answer.
---
- `--parallel 4`
- `-c 2048` (4 slots x 512 tokens; the KV cache is only about 50 MB, memory stays near 270 MB)
- keep the memory limit at 400Mi.
---
    kubectl apply -f solution/llm.yaml      # from the lesson directory
    kubectl rollout status deploy/llm
