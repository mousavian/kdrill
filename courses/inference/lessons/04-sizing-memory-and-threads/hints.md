    kubectl describe pod -l app=llm | grep -A6 'Last State'
    kubectl logs deploy/llm --previous | tail

Memory = weights + KV cache + a little. For this model the weights are ~105 MB, the
runtime ~100 MB, and the KV cache costs about 23 KB for every token of context in
`-c`. `-c` is the TOTAL context shared by `--parallel` slots: with `-c 32768 --parallel 4`
each conversation could be 8192 tokens long. How long does yours need to be?
---
- 4 slots x 1024 tokens needs `-c 4096`: KV cache about 95 MB, peak memory ~300 MB.
- Then set `limits.memory` and `requests.memory` to the same value, 15% or more above the peak
  (`kubectl exec deploy/llm -- grep VmHWM /proc/1/status`), at most 450Mi: 400Mi works.
- `-t` should not exceed the CPU limit (2 cores here).
---
    kubectl apply -f solution/llm.yaml      # from the lesson directory
