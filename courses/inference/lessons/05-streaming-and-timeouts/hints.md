Send the request yourself and watch where it stops:

    kubectl exec client -- ask -s -t 30 -w 40 http://edge/v1/chat/completions
    kubectl exec client -- curl -sN http://edge/v1/chat/completions -H 'content-type: application/json' \
      -d '{"model":"tiny","stream":true,"max_tokens":30,"messages":[{"role":"user","content":"hi"}]}'

Look at every object that mentions a time: `kubectl get httproute,clienttrafficpolicy -o yaml | grep -i -B3 timeout`.
The model needs 3 s before its first token, then ~3 s for the rest.
---
Two settings fire too early:

- HTTPRoute `rules[].timeouts.request: 3s` limits the whole request/response; a stream
  is one long response. Use `0s` (disabled) or something above your longest generation.
- ClientTrafficPolicy `timeout.http.streamIdleTimeout: 2s` closes a stream with no
  bytes for 2 s: that is the model thinking before the first token. Raise it above
  your worst time to first token (60s).
---
    kubectl apply -f solution/gateway.yaml      # from the lesson directory
    kubectl exec client -- ask -s -t 30 -w 40 http://edge/v1/chat/completions
