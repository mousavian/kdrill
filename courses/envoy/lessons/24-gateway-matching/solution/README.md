# Solution

From the lesson directory:

    kubectl apply -f solution/routes.yaml

The api route's rules:

    - backendRefs: [{name: api-v1, port: 80}]
    - matches:
      - path: {type: PathPrefix, value: /v2}
      - headers: [{name: x-api-version, value: "2"}]
      - queryParams: [{name: canary, value: "true"}]
      backendRefs: [{name: api-v2, port: 80}]
    - matches:
      - path: {type: Exact, value: /orders}
        method: POST
      backendRefs: [{name: orders, port: 80}]

and the web route gets `hostnames: ["www.lab", "*.lab"]`.

Gateway API semantics that differ from hand-written Envoy routes:
- **Precedence, not order.** Across all rules of all routes for a hostname,
  the implementation must pick: Exact path over PathPrefix; longer prefix
  over shorter; a match with a method over one without; more header
  matches; more query param matches; then the oldest route; then
  alphabetical. Envoy Gateway sorts the generated Envoy routes that way.
  Look at the result in the config dump (`kubectl port-forward deploy/edge
  19000`): the header and query matches come before the bare `/` route.
- **PathPrefix is per path element**: `/v2` matches `/v2` and `/v2/x`, not
  `/v2beta` (Envoy's `path_separated_prefix`, lesson 03).
- **Hostname precedence**: an exact hostname beats a wildcard, so `api.lab`
  goes to the api route even though `*.lab` also matches.
- No `matches` means `PathPrefix: /`.

Takeaways: think in matches and precedence; order in YAML is only a tie
breaker for identical matches.
