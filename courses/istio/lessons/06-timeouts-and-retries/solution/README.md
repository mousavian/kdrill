# Solution

    kubectl apply -f solution/virtualservice.yaml

Route `main` gets `timeout: 2s` and `retries: {attempts: 3, retryOn:
5xx,connect-failure,reset}`.

- `/delay/5`: after 2 s Envoy resets the request and answers 504 with body
  `upstream request timeout`. The overall timeout includes retries, so a
  slow backend cannot turn into 4 x 5 seconds.
- `/unstable?failure_rate=0.4`: a request now fails only if all 4 attempts
  fail, 0.4^4 = 2.6% instead of 40%.
- `/status/500`: inventory logs the request 4 times; the 4th carries
  `X-Envoy-Attempt-Count: 4`. The client still gets the final 500.

In the client sidecar (`istioctl proxy-config routes deploy/web -n shop
--name 8000 -o json`): `"timeout": "2s"` and a `retryPolicy` with
`"numRetries": 3` and `"retryOn": "5xx,connect-failure,reset"`, plus
Istio's `retryHostPredicate` (`previous_hosts`) so a retry prefers
another endpoint.

Takeaways:
- Set explicit timeouts: Istio's default is none for HTTP.
- `attempts` counts retries; retrying 500s needs `5xx` in `retryOn`.
- Retry at one layer only, and only idempotent requests.
