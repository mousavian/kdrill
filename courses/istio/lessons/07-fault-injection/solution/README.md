# Solution

    kubectl apply -f solution/virtualservice.yaml

Four routes, evaluated in order:

| Route | Match | Fault |
|---|---|---|
| chaos-abort | `x-chaos: abort` | abort 503, 100% |
| chaos-delay | `x-chaos: delay` | delay 2s, 100% |
| chaos-flaky | `x-chaos: flaky` | abort 500, 50% |
| main | (anything else) | none |

All four send to `ratings`. In `web`'s sidecar each route carries a
`typedPerFilterConfig` for `envoy.filters.http.fault`; the abort body is
`fault filter abort`, and if access logs were on (lesson 12) these requests
would show the response flag `FI` (abort) or `DI` (delay).

A useful exercise: add `timeout: 1s` to route `chaos-delay` and watch the
delayed request turn into a 504. That is how you prove a caller's timeout
works.

Takeaways:
- Faults are injected by the caller's proxy, before the request leaves.
- Always scope faults with a match; percentage controls the blast radius.
