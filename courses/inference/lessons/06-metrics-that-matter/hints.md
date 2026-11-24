    kubectl exec client -- curl -s http://llm/metrics | head      # an error until the flag is set
    kubectl exec client -- curl -s http://llm/props | head -c 300 # no metrics here; see the server's --help for --metrics

llama.cpp turns its Prometheus endpoint on with a flag. Metrics are per pod; with one
replica `http://llm/metrics` reaches it. HELP lines say what each metric means,
and TYPE says counter (only goes up: take a rate) or gauge (a value now).
---
1. Add `--metrics` to the server args (the pod restarts; the users keep going).
2. Read `kubectl exec client -- curl -s http://llm/metrics | grep -E '^llamacpp'`:
   - waiting = `llamacpp:requests_deferred`, running = `llamacpp:requests_processing`;
   - generated tokens = the counter `llamacpp:tokens_predicted_total`; take it twice 10 s
     apart and divide the difference by 10.
3. Create the ConfigMap:

       kubectl create configmap findings \
         --from-literal=waiting-metric=llamacpp:requests_deferred \
         --from-literal=running-metric=llamacpp:requests_processing \
         --from-literal=tokens-metric=llamacpp:tokens_predicted_total \
         --from-literal=queue-depth=2 --from-literal=tokens-per-second=<your number>
---
    kubectl apply -f solution/llm.yaml          # from the lesson directory
    kubectl rollout status deploy/llm --timeout=120s
    bash solution/findings.sh                   # reads the live numbers and creates the ConfigMap
