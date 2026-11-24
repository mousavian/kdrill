    kubectl exec client -- ask -v -n 6 -t 10 -w 14 -H 'x-api-key: alice' http://edge/v1/chat/completions     # slow: queued behind mallory
    kubectl explain backendtrafficpolicy.spec.rateLimit.local.rules

A rate limit rule can match clients by header. With `type: Distinct` a separate counter (token bucket) is kept for every
different value of the header, so mallory and alice have their own budgets. Without the Distinct selector there would be one shared budget
for everybody. Which unit and how many requests per second leave room for others?
---
BackendTrafficPolicy on HTTPRoute `llm`:

    rateLimit:
      type: Local
      local:
        rules:
        - clientSelectors:
          - headers: [{name: x-api-key, type: Distinct}]
          limit: {requests: 2, unit: Second}
---
    kubectl apply -f solution/limit.yaml      # from the lesson directory
