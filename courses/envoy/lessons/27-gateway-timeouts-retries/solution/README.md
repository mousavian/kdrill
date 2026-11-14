# Solution

From the lesson directory:

    kubectl apply -f solution/routes.yaml

The HTTPRoute rules get `timeouts: {request: 1s}` and `{request: 10s}`,
and a BackendTrafficPolicy attaches retries to the route:

    apiVersion: gateway.envoyproxy.io/v1alpha1
    kind: BackendTrafficPolicy
    metadata: {name: api-retries}
    spec:
      targetRefs:
      - {group: gateway.networking.k8s.io, kind: HTTPRoute, name: api}
      retry:
        numRetries: 2
        retryOn:
          triggers: [connect-failure, retriable-status-codes]
          httpStatusCodes: [503]
        perRetry:
          backOff: {baseInterval: 10ms, maxInterval: 100ms}

In Envoy (port-forward to `deploy/edge`, `config_dump`): the routes get
`timeout: 1s` / `10s` and a `retry_policy` with `retry_on:
connect-failure,retriable-status-codes`, `retriable_status_codes: [503]`,
`num_retries: 2`, and Envoy Gateway adds the `previous_hosts` predicate
(lesson 09), so a retry goes to another pod.

Notes:
- `timeouts.request` is the whole client request (Envoy route
  `timeout`), `timeouts.backendRequest` one attempt (Envoy
  `per_try_timeout`); `request` must be at least `backendRequest`.
- **Policy attachment**: Envoy Gateway's policies attach to a Gateway (all
  its routes), a listener (`sectionName`), a route, or a route rule
  (`sectionName` = rule name). The more specific one wins, unless the
  policy sets `mergeType`. Policies report status per ancestor Gateway.
- These retries apply to every method, including POST. To limit retries
  to safe methods, split the route by method (lesson 24) and attach the
  policy to the GET rule only (`sectionName`).
- The experimental Gateway API channel (installed here) also has
  `rules[].retry` (`codes`, `attempts`, `backoff`) on the HTTPRoute itself;
  expect that to become the portable way.
