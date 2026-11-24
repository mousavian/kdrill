# Solution

From the lesson directory:

    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

    - match: {prefix: "/api/"}
      route:
        cluster: api
        prefix_rewrite: "/"
        host_rewrite_literal: api.internal
      request_headers_to_add:
      - header: {key: x-env, value: lab}
        append_action: OVERWRITE_IF_EXISTS_OR_ADD
      request_headers_to_remove: [x-debug-token]
      response_headers_to_add:
      - header: {key: x-served-by, value: envoy-lab}

Notes:
- `prefix_rewrite` replaces exactly the matched prefix, so mind the
  slashes: `prefix: /api` with `prefix_rewrite: /` would also match
  `/apiary` and turn it into `/ary`. For anything fancier use
  `regex_rewrite` (RE2 with `\1` groups). The query string is kept.
- `append_action` defaults to `APPEND_IF_EXISTS_OR_ADD`: a client sending
  `x-env: prod` would reach the backend with *two* values. For headers the
  backend trusts (identity, environment, tenant), always overwrite, or
  remove the client's copy first.
- Header values can use command operators like the access log:
  `%DOWNSTREAM_REMOTE_ADDRESS_WITHOUT_PORT%`, `%REQ(x-user)%`,
  `%UPSTREAM_HOST%` (responses), `%START_TIME%`.
- Edits on the route config, virtual host and route all apply; by default
  the most specific level is applied last (`most_specific_header_mutations_wins`
  changes that).
- Envoy sets some headers itself: `x-request-id` (generated if missing),
  `x-forwarded-proto`, `x-envoy-expected-rq-timeout-ms`, and
  `x-forwarded-for` when `use_remote_address` is true (edge proxies).
  Responses carry `x-envoy-upstream-service-time` and `server: envoy`
  unless configured otherwise.

Takeaways: rewrites decouple public URLs from internal ones; header edits
are a security control, so overwrite anything you rely on downstream.
